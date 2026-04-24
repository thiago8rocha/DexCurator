import 'package:flutter/material.dart';
import 'package:dexcurator/core/pokemon_types.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, calculateWeaknesses, PokeballLoader, TypeBadge;
import 'package:dexcurator/services/dex_bundle_service.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/teams_storage_service.dart';
import 'package:dexcurator/screens/menu/teams_screen.dart'
    show TeamsGamePickerSheet, kTeamsGamesByGen, gameById;

// ─── Classificação de papel por tipo ─────────────────────────────
// Baseado no tipo primário do Pokémon — sem precisar de stats da API.
// Atacante: tipos com alto potencial ofensivo
// Defensor: tipos naturalmente defensivos/bulky
// Suporte:  tipos com foco em controle, status, utilidade
enum TeamRole { attacker, defender, support }

const _defenderTypes  = {'steel', 'rock', 'normal', 'ground', 'fairy'};
const _supportTypes   = {'psychic', 'ghost', 'dark', 'poison'};

TeamRole roleOf(List<String> types) {
  if (types.isEmpty) return TeamRole.attacker;
  final t = types[0].toLowerCase();
  if (_defenderTypes.contains(t))  return TeamRole.defender;
  if (_supportTypes.contains(t))   return TeamRole.support;
  return TeamRole.attacker;
}

String roleName(TeamRole r) => switch (r) {
  TeamRole.attacker => 'Atacante',
  TeamRole.defender => 'Defensor',
  TeamRole.support  => 'Suporte',
};

Color roleColor(TeamRole r) => switch (r) {
  TeamRole.attacker => const Color(0xFF378ADD),
  TeamRole.defender => const Color(0xFF1D9E75),
  TeamRole.support  => const Color(0xFF9E6E1D),
};

// ─── Análise do time ──────────────────────────────────────────────
class TeamAnalysis {
  final Map<TeamRole, List<int>> roles;
  final List<String> uncovered;   // tipos sem cobertura ofensiva
  final List<String> sharedWeak;  // tipos com 2+ membros fracos

  const TeamAnalysis({
    required this.roles,
    required this.uncovered,
    required this.sharedWeak,
  });

  int get attackers  => roles[TeamRole.attacker]?.length ?? 0;
  int get defenders  => roles[TeamRole.defender]?.length ?? 0;
  int get supporters => roles[TeamRole.support]?.length  ?? 0;

  bool get isBalanced => attackers >= 1 && defenders >= 1;

  String? get mainTip {
    if (defenders == 0) return 'Nenhum Defensor — o time pode ser derrubado facilmente.';
    if (attackers == 0) return 'Nenhum Atacante — o time não consegue ganhar batalhas.';
    if (attackers >= 4) return 'Muitos Atacantes — considere um Defensor ou Suporte.';
    if (defenders >= 3) return 'Muitos Defensores — o time pode ter dificuldade em causar dano.';
    if (sharedWeak.isNotEmpty) return 'Fraqueza crítica';
    return null;
  }
}

const _offChart = {
  'normal':   <String>[],
  'fire':     ['grass', 'ice', 'bug', 'steel'],
  'water':    ['fire', 'ground', 'rock'],
  'electric': ['water', 'flying'],
  'grass':    ['water', 'ground', 'rock'],
  'ice':      ['grass', 'ground', 'flying', 'dragon'],
  'fighting': ['normal', 'ice', 'rock', 'dark', 'steel'],
  'poison':   ['grass', 'fairy'],
  'ground':   ['fire', 'electric', 'poison', 'rock', 'steel'],
  'flying':   ['grass', 'fighting', 'bug'],
  'psychic':  ['fighting', 'poison'],
  'bug':      ['grass', 'psychic', 'dark'],
  'rock':     ['fire', 'ice', 'flying', 'bug'],
  'ghost':    ['psychic', 'ghost'],
  'dragon':   ['dragon'],
  'dark':     ['psychic', 'ghost'],
  'steel':    ['ice', 'rock', 'fairy'],
  'fairy':    ['fighting', 'dragon', 'dark'],
};

TeamAnalysis analyzeTeam(List<int> members) {
  final svc = PokedexDataService.instance;

  // Papéis
  final roles = <TeamRole, List<int>>{
    TeamRole.attacker: [],
    TeamRole.defender: [],
    TeamRole.support:  [],
  };
  for (final id in members) {
    final role = roleOf(svc.getTypes(id));
    roles[role]!.add(id);
  }

  // Cobertura ofensiva
  final covered = <String>{};
  for (final id in members)
    for (final t in svc.getTypes(id))
      for (final target in _offChart[t.toLowerCase()] ?? <String>[])
        covered.add(target);
  final uncovered = kAllTypes.where((t) => !covered.contains(t)).toList();

  // Fraquezas compartilhadas (2+ membros)
  final weakCount = <String, int>{};
  for (final id in members)
    calculateWeaknesses(svc.getTypes(id)).forEach((k, v) {
      if (v >= 2.0) weakCount[k] = (weakCount[k] ?? 0) + 1;
    });
  final sharedWeak = weakCount.entries
      .where((e) => e.value >= 2)
      .map((e) => e.key)
      .toList();

  return TeamAnalysis(roles: roles, uncovered: uncovered, sharedWeak: sharedWeak);
}

// ─── Tela ─────────────────────────────────────────────────────────
class TeamBuilderScreen extends StatefulWidget {
  final Map<String, dynamic> activeGame;
  final PokemonTeam?         existing;
  const TeamBuilderScreen({super.key,
      required this.activeGame, this.existing});
  @override State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  List<int>   _members   = [];
  List<int>   _available = [];
  List<int>   _filtered  = [];
  bool        _loading   = true;
  String      _search    = '';
  String?     _typeFilter;
  late TextEditingController _nameCtrl;
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _members  = List.from(widget.existing?.members ?? []);
    _nameCtrl = TextEditingController(
        text: widget.existing?.name ?? 'Meu Time');
    _searchCtrl = TextEditingController();
    _loadAvailable();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _searchCtrl.dispose(); super.dispose();
  }

  Future<void> _loadAvailable() async {
    final sections = PokeApiService.pokedexSections[widget.activeGame['id']] ?? [];
    final ids = <int>{};
    for (final s in sections) {
      final entries = await DexBundleService.instance.loadSection(s.apiName);
      if (entries != null) for (final e in entries) ids.add(e['speciesId']!);
    }
    if (ids.isEmpty) for (int i = 1; i <= 1025; i++) ids.add(i);
    final sorted = ids.toList()..sort();
    if (mounted) setState(() {
      _available = sorted;
      _applyFilters();
      _loading   = false;
    });
  }

  void _applyFilters() {
    var list = _available;
    if (_typeFilter != null) {
      list = list.where((id) =>
          PokedexDataService.instance.getTypes(id).contains(_typeFilter))
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((id) =>
          PokedexDataService.instance.getName(id).toLowerCase().contains(q) ||
          id.toString() == q).toList();
    }
    _filtered = list;
  }

  void _toggle(int id) {
    setState(() {
      if (_members.contains(id)) {
        _members.remove(id);
      } else if (_members.length < 6) {
        _members.add(id);
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _nameCtrl.text = 'Meu Time'; return; }
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adicione pelo menos 1 Pokémon.')));
      return;
    }
    final gameId   = widget.activeGame['id']   as String;
    final gameName = widget.activeGame['name'] as String;
    if (widget.existing == null) {
      final canSave = await TeamsStorageService.instance.canSave(gameId);
      if (!canSave && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            'Limite de ${TeamsStorageService.maxPerGame} times por jogo.')));
        return;
      }
    }
    final team = PokemonTeam(
      id:       widget.existing?.id ?? TeamsStorageService.newId(),
      gameId:   gameId,
      gameName: gameName,
      name:     name,
      members:  List.from(_members),
    );
    await TeamsStorageService.instance.save(team);
    if (mounted) Navigator.pop(context);
  }

  void _showTypeFilter() async {
    final all = kAllTypes;
    final result = await showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TypeFilterSheet(selected: _typeFilter, types: all),
    );
    if (mounted) setState(() { _typeFilter = result; _applyFilters(); });
  }

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final title    = widget.existing == null ? 'Criar Time' : 'Editar Time';
    final analysis = _members.length >= 2 ? analyzeTeam(_members) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Badge(isLabelVisible: _typeFilter != null,
            child: IconButton(icon: const Icon(Icons.filter_list_outlined),
                onPressed: _showTypeFilter)),
          TextButton(onPressed: _save,
              child: const Text('Salvar',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
      body: Column(children: [

        // ── Nome ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nome do time',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // ── Slots ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: List.generate(6, (i) {
            final filled = i < _members.length;
            final types  = filled
                ? PokedexDataService.instance.getTypes(_members[i])
                : <String>[];
            final tc = types.isNotEmpty ? typeColor(types[0]) : null;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: filled ? () => _toggle(_members[i]) : null,
                child: AspectRatio(aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: filled
                          ? tc?.withOpacity(0.15)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: filled
                              ? (tc?.withOpacity(0.5) ?? scheme.primary)
                              : scheme.outlineVariant,
                          width: filled ? 1.5 : 0.5)),
                    child: filled
                        ? Stack(children: [
                            Positioned.fill(child: Image.asset(
                                'assets/sprites/artwork/${_members[i]}.webp',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.catching_pokemon, size: 20,
                                        color: scheme.onSurfaceVariant))),
                            Positioned(top: 2, right: 2,
                                child: Icon(Icons.remove_circle,
                                    size: 14, color: scheme.error)),
                          ])
                        : Icon(Icons.add, size: 18,
                            color: scheme.onSurfaceVariant.withOpacity(0.3)),
                  ),
                ),
              ),
            ));
          })),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text('${_members.length}/6 Pokémon',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ),

        // ── Análise em tempo real ─────────────────────────────────
        if (analysis != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _AnalysisPanel(analysis: analysis, members: _members),
          ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // ── Busca ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() { _search = v; _applyFilters(); }),
            decoration: InputDecoration(
              hintText: 'Buscar Pokémon...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: scheme.outlineVariant)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: scheme.outlineVariant)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ),

        if (_typeFilter != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(ptType(_typeFilter!),
                      style: TextStyle(fontSize: 11,
                          color: scheme.onPrimaryContainer)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() {
                      _typeFilter = null; _applyFilters();
                    }),
                    child: Icon(Icons.close, size: 13,
                        color: scheme.onPrimaryContainer)),
                ]),
              ),
            ]),
          ),

        // ── Grid ──────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(child: PokeballLoader())
              : _filtered.isEmpty
                  ? Center(child: Text('Nenhum Pokémon encontrado.',
                      style: TextStyle(color: scheme.onSurfaceVariant)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, childAspectRatio: 0.85,
                              crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final id    = _filtered[i];
                        final name  = PokedexDataService.instance.getName(id);
                        final types = PokedexDataService.instance.getTypes(id);
                        final inTeam  = _members.contains(id);
                        final full    = _members.length >= 6 && !inTeam;
                        return _PokemonGridCell(
                          id: id, name: name, types: types,
                          inTeam: inTeam, disabled: full,
                          onTap: () => _toggle(id),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ─── Painel de análise em tempo real ─────────────────────────────
class _AnalysisPanel extends StatefulWidget {
  final TeamAnalysis analysis;
  final List<int>    members;
  const _AnalysisPanel({required this.analysis, required this.members});
  @override State<_AnalysisPanel> createState() => _AnalysisPanelState();
}

class _AnalysisPanelState extends State<_AnalysisPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final analysis = widget.analysis;
    final svc      = PokedexDataService.instance;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Column(children: [

        // ── Header clicável ───────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(children: [
              Expanded(
                child: analysis.mainTip != null
                    ? Text(analysis.mainTip!,
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500,
                          color: analysis.isBalanced
                              ? scheme.onSurface
                              : const Color(0xFFE65100)))
                    : Text('Time equilibrado',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: const Color(0xFF1D9E75))),
              ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),

        // ── Conteúdo expansível ───────────────────────────────────
        if (_expanded) ...[
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // Roles com membros identificados
              for (final role in TeamRole.values) ...[
                _RoleRow(
                  role:    role,
                  members: analysis.roles[role] ?? [],
                  scheme:  scheme,
                  svc:     svc,
                ),
                if (role != TeamRole.support) const SizedBox(height: 8),
              ],

              const SizedBox(height: 12),

              // Fraquezas críticas — badges de tipo
              if (analysis.sharedWeak.isNotEmpty) ...[
                Row(children: [
                  Text('Fraqueza crítica:',
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE65100))),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 4, runSpacing: 4,
                  children: analysis.sharedWeak.map((t) => Container(
                    width: 64, height: 16,
                    decoration: BoxDecoration(
                        color: typeColor(t),
                        borderRadius: BorderRadius.zero),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/types/${t.toLowerCase()}.png',
                            width: 10, height: 10,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 10)),
                        const SizedBox(width: 2),
                        Text(typeName(t), style: const TextStyle(
                            fontSize: 7, color: Colors.white,
                            fontWeight: FontWeight.w700)),
                      ]),
                  )).toList()),
                const SizedBox(height: 12),
              ],

              Divider(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 10),

              // Cobertura de tipos — badges visuais
              Row(children: [
                Text('Cobertura',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                const SizedBox(width: 6),
                Text('${kAllTypes.length - analysis.uncovered.length}/18',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: analysis.uncovered.isEmpty
                            ? const Color(0xFF1D9E75)
                            : scheme.onSurface)),
              ]),

              if (analysis.uncovered.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Tipos sem cobertura:',
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                // Badges compactos dos tipos pendentes
                Wrap(spacing: 4, runSpacing: 4,
                  children: analysis.uncovered.map((t) => Container(
                    width: 64, height: 16,
                    decoration: BoxDecoration(
                        color: typeColor(t).withOpacity(0.85),
                        borderRadius: BorderRadius.zero),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/types/${t.toLowerCase()}.png',
                            width: 10, height: 10,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 10)),
                        const SizedBox(width: 2),
                        Text(typeName(t), style: const TextStyle(
                            fontSize: 7, color: Colors.white,
                            fontWeight: FontWeight.w700)),
                      ]),
                  )).toList()),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Todos os tipos cobertos',
                      style: TextStyle(
                          fontSize: 10, color: const Color(0xFF1D9E75))),
                ),

            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Linha de papel com membros ───────────────────────────────────
class _RoleRow extends StatelessWidget {
  final TeamRole      role;
  final List<int>     members;
  final ColorScheme   scheme;
  final PokedexDataService svc;
  const _RoleRow({required this.role, required this.members,
      required this.scheme, required this.svc});

  @override
  Widget build(BuildContext context) {
    final color  = roleColor(role);
    final label  = roleName(role);
    final empty  = members.isEmpty;

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Label do papel
      SizedBox(width: 64, child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: empty ? scheme.onSurfaceVariant.withOpacity(0.5) : color))),

      // Sprites dos membros desse papel
      if (!empty)
        ...members.map((id) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: svc.getName(id),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: typeColor(svc.getTypes(id).isNotEmpty
                    ? svc.getTypes(id)[0] : 'normal').withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: color.withOpacity(0.4), width: 1)),
              child: Image.asset(
                'assets/sprites/artwork/$id.webp',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                    Icons.catching_pokemon, size: 16,
                    color: scheme.onSurfaceVariant.withOpacity(0.4)),
              ),
            ),
          ),
        ))
      else
        Text('Nenhum',
            style: TextStyle(
                fontSize: 10, color: scheme.onSurfaceVariant.withOpacity(0.5),
                fontStyle: FontStyle.italic)),
    ]);
  }
}

// ─── Célula do grid ───────────────────────────────────────────────
class _PokemonGridCell extends StatelessWidget {
  final int id; final String name; final List<String> types;
  final bool inTeam, disabled; final VoidCallback onTap;
  const _PokemonGridCell({required this.id, required this.name,
      required this.types, required this.inTeam,
      required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tc1 = types.isNotEmpty
        ? typeColor(types[0]) : scheme.surfaceContainerHighest;
    final tc2 = types.length > 1 ? typeColor(types[1]) : tc1;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: !disabled ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: inTeam
                ? [tc1.withOpacity(0.55), tc2.withOpacity(0.40)]
                : [tc1.withOpacity(0.35), tc2.withOpacity(0.22)],
          ) : null,
          color: disabled ? scheme.surfaceContainer : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: inTeam
                  ? tc1.withOpacity(0.75)
                  : tc1.withOpacity(0.45),
              width: inTeam ? 2.0 : 1.0)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(flex: 3, child: Image.asset(
                'assets/sprites/artwork/$id.webp',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                    Icons.catching_pokemon, size: 32,
                    color: scheme.onSurfaceVariant.withOpacity(0.4)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Column(children: [
                Text(name, style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: disabled
                        ? scheme.onSurfaceVariant.withOpacity(0.4)
                        : scheme.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                // Badges compactos — FittedBox evita overflow
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: types.take(2).map((t) =>
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 64, height: 14,
                        decoration: BoxDecoration(
                          color: typeColor(t),
                          borderRadius: BorderRadius.zero),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/types/${t.toLowerCase()}.png',
                                width: 12, height: 12,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox(width: 12)),
                            const SizedBox(width: 2),
                            Text(typeName(t), style: const TextStyle(
                                fontSize: 8, color: Colors.white,
                                fontWeight: FontWeight.w700)),
                          ]),
                      )
                    ).toList(),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filtro de tipo ───────────────────────────────────────────────
class _TypeFilterSheet extends StatelessWidget {
  final String? selected; final List<String> types;
  const _TypeFilterSheet({required this.selected, required this.types});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Filtrar por tipo',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (selected != null)
            TextButton(onPressed: () => Navigator.pop(context, null),
                child: const Text('Limpar')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6,
          children: types.map((t) {
            final sel = selected == t;
            final tc  = typeColor(t);
            return GestureDetector(
              onTap: () => Navigator.pop(context, t),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: sel ? tc : Colors.transparent, width: 2)),
                child: TypeBadge(type: t),
              ),
            );
          }).toList()),
      ]),
    );
  }
}
