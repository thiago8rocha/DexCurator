import 'package:flutter/material.dart';
import 'package:dexcurator/core/pokemon_types.dart'
    show typeColor, typeEffectiveness, kAllTypes, typeName;
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, SectionCard, bilingualModeNotifier;
import 'package:dexcurator/screens/detail/mainline_detail_screen.dart';
import 'package:dexcurator/screens/detail/nacional_detail_screen.dart';
import 'package:dexcurator/models/pokemon.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/translations.dart';
import 'package:dexcurator/screens/menu/moves_list_screen.dart' show MoveEntry;

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

// ─── Ordem e labels dos métodos ──────────────────────────────────
const _methodOrder = ['level-up', 'machine', 'egg', 'tutor'];
const _methodTabLabels = {
  'level-up': 'Nível',
  'machine':  'TM / HM',
  'egg':      'Ovos',
  'tutor':    'Tutor',
};

// ─── Sheet principal ─────────────────────────────────────────────
class MoveDetailSheet extends StatefulWidget {
  final MoveEntry entry;
  final String    activeGameId;
  const MoveDetailSheet({super.key, required this.entry, required this.activeGameId});
  @override State<MoveDetailSheet> createState() => _MoveDetailSheetState();
}

class _MoveDetailSheetState extends State<MoveDetailSheet> {
  String _resolvedTitle(String mode) {
    final nameEn = _titleCase(widget.entry.nameEn.replaceAll('-', ' '));
    final namePt = translateMove(widget.entry.nameEn);
    if (mode == 'pt') return namePt;
    return nameEn;
  }

  Future<void> _openPokemon(BuildContext ctx, int id) async {
    final svc  = PokedexDataService.instance;
    final poke = Pokemon(
      id: id, entryNumber: id, name: svc.getName(id), types: svc.getTypes(id),
      baseHp: 0, baseAttack: 0, baseDefense: 0,
      baseSpAttack: 0, baseSpDefense: 0, baseSpeed: 0,
      spriteUrl:      'assets/sprites/artwork/$id.webp',
      spritePixelUrl: 'assets/sprites/pixel/$id.webp',
      spriteHomeUrl:  'assets/sprites/home/$id.webp',
    );
    final lastDex  = widget.activeGameId;
    final isCaught = await StorageService().isCaught(lastDex, id);
    if (!ctx.mounted) return;
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => lastDex == 'nacional'
          ? NacionalDetailScreen(
              pokemon: poke, caught: isCaught, pokedexId: 'nacional',
              onToggleCaught: () async {
                final cur = await StorageService().isCaught(lastDex, id);
                await StorageService().setCaught(lastDex, id, !cur);
              })
          : SwitchDetailScreen(
              pokemon: poke, caught: isCaught, pokedexId: lastDex,
              onToggleCaught: () async {
                final cur = await StorageService().isCaught(lastDex, id);
                await StorageService().setCaught(lastDex, id, !cur);
              }),
    ));
  }

  Color _catColor(String cat) {
    if (cat == 'physical') return const Color(0xFFE24B4A);
    if (cat == 'special')  return const Color(0xFF9C27B0);
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final entry   = widget.entry;
    final typeEn  = entry.typeEn;
    final typePt  = typeEn.isNotEmpty ? ptType(typeEn) : '';
    final tColor  = typeEn.isNotEmpty ? typeColor(typeEn) : scheme.surfaceContainerHighest;
    final catName = entry.category;

    return ValueListenableBuilder<String>(
      valueListenable: bilingualModeNotifier,
      builder: (ctx, mode, _) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize:     0.4,
        maxChildSize:     0.95,
        expand:           false,
        builder: (ctx, scrollController) => Column(children: [
          // ── Handle ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Nome do golpe ──
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_resolvedTitle(mode),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),

          // ── Conteúdo scrollável ──
          Expanded(child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [

              // ── Tipo + Categoria (tamanho fixo, centralizados) ──
              Center(
                child: SizedBox(
                  width: 260,
                  child: Row(children: [
                    if (typeEn.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: tColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Image.asset(typeIconAsset(typeEn),
                                width: 14, height: 14,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox(width: 14)),
                            const SizedBox(width: 4),
                            Text(typePt, style: const TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                          ]),
                        ),
                      ),
                    if (typeEn.isNotEmpty && catName.isNotEmpty)
                      const SizedBox(width: 8),
                    if (catName.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _catColor(catName).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: _catColor(catName).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Image.asset('assets/categories/$catName.png',
                                width: 35, height: 14, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox()),
                            const SizedBox(width: 4),
                            Text(
                              catName == 'physical' ? 'Físico'
                                  : catName == 'special' ? 'Especial'
                                  : 'Status',
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _catColor(catName)),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // ── STATUS ──
              SectionCard(
                title: 'STATUS',
                pokemonTypes: typeEn.isNotEmpty ? [typeEn] : [],
                child: Row(children: [
                  _StatBox(
                      entry.power    != null ? '${entry.power}'    : '—',
                      'Poder'),
                  _VDivider(),
                  _StatBox(
                      entry.accuracy != null ? '${entry.accuracy}%': '—',
                      'Precisão'),
                  _VDivider(),
                  _StatBox(
                      entry.pp       != null ? '${entry.pp}'       : '—',
                      'PP'),
                ]),
              ),

              if (entry.flavor.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'DESCRIÇÃO NO JOGO',
                  pokemonTypes: const [],
                  child: Text(entry.flavor,
                      style: TextStyle(fontSize: 13,
                          color: scheme.onSurface, height: 1.5)),
                ),
              ],

              if (entry.effect.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'EFEITO',
                  pokemonTypes: const [],
                  child: Text(entry.effect,
                      style: TextStyle(fontSize: 13,
                          color: scheme.onSurface, height: 1.5)),
                ),
              ],

              if (typeEn.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'EFETIVIDADE',
                  pokemonTypes: [typeEn],
                  child: _TypeEffectiveness(moveType: typeEn),
                ),
              ],

              const SizedBox(height: 16),
              _PokemonTabCard(
                  methodGroups: entry.methodGroups,
                  fallbackIds:  entry.pokemonIds,
                  onTap:        _openPokemon),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── STATUS widgets ───────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String value, label;
  const _StatBox(this.value, this.label);
  @override Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override Widget build(BuildContext context) => Container(
    width: 0.5, height: 52,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

// ─── Efetividade de tipos (centralizada) ─────────────────────────
class _TypeEffectiveness extends StatelessWidget {
  final String moveType;
  const _TypeEffectiveness({required this.moveType});

  @override
  Widget build(BuildContext context) {
    final superEff = <String>[];
    final notEff   = <String>[];
    final immune   = <String>[];
    final neutral  = <String>[];

    for (final defType in kAllTypes) {
      final mult = typeEffectiveness[defType]?[moveType] ?? 1.0;
      if (mult >= 2.0)      superEff.add(defType);
      else if (mult <= 0.0) immune.add(defType);
      else if (mult < 1.0)  notEff.add(defType);
      else                  neutral.add(defType);
    }

    return Column(children: [
      if (superEff.isNotEmpty) ...[
        _EffLabel('Super Efetivo', '2× de dano'),
        const SizedBox(height: 6),
        _TypeWrap(superEff),
        const SizedBox(height: 12),
      ],
      if (notEff.isNotEmpty) ...[
        _EffLabel('Pouco Efetivo', '½× de dano'),
        const SizedBox(height: 6),
        _TypeWrap(notEff),
        const SizedBox(height: 12),
      ],
      if (immune.isNotEmpty) ...[
        _EffLabel('Sem Efeito', '0× de dano'),
        const SizedBox(height: 6),
        _TypeWrap(immune),
        const SizedBox(height: 12),
      ],
      _EffLabel('Dano Normal', '1× de dano'),
      const SizedBox(height: 6),
      neutral.isEmpty
          ? Text('—', style: TextStyle(fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant))
          : _TypeWrap(neutral),
    ]);
  }
}

class _EffLabel extends StatelessWidget {
  final String text, mult;
  const _EffLabel(this.text, this.mult);
  @override Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, children: [
      Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: color)),
      const SizedBox(width: 6),
      Text(mult, style: TextStyle(fontSize: 10, color: color)),
    ]);
  }
}

class _TypeWrap extends StatelessWidget {
  final List<String> types;
  const _TypeWrap(this.types);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4, runSpacing: 4,
      children: types.map((t) {
        final tc = typeColor(t);
        return Container(
          width: 64, height: 14,
          color: tc,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset(typeIconAsset(t), width: 12, height: 12,
                errorBuilder: (_, __, ___) => const SizedBox(width: 12)),
            const SizedBox(width: 2),
            Text(typeName(t), style: const TextStyle(fontSize: 8,
                fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        );
      }).toList(),
    );
  }
}

// ─── Pokémon com abas por método ─────────────────────────────────
class _PokemonTabCard extends StatefulWidget {
  final Map<String, List<int>>               methodGroups;
  final List<int>                            fallbackIds;
  final Future<void> Function(BuildContext, int) onTap;
  const _PokemonTabCard({
    required this.methodGroups,
    required this.fallbackIds,
    required this.onTap,
  });
  @override State<_PokemonTabCard> createState() => _PokemonTabCardState();
}

class _PokemonTabCardState extends State<_PokemonTabCard>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late List<String>  _methods;

  @override
  void initState() {
    super.initState();
    // Se há dados de método, mostra sempre os 4 tabs (com msg de vazio quando necessário).
    // Se não há dados de método nenhum, cai no flat list.
    if (widget.methodGroups.isNotEmpty) {
      _methods = [..._methodOrder];
    } else {
      _methods = [];
    }
    final count = _methods.isEmpty ? 1 : _methods.length;
    _tab = TabController(length: count, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final tColor     = const Color(0xFF888888);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final scheme     = Theme.of(context).colorScheme;

    final hasGroups = _methods.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          width: double.infinity,
          decoration: BoxDecoration(
            color: tColor.withValues(alpha: isDark ? 0.08 : 0.06),
            border: Border.all(color: tColor.withValues(alpha: 0.3), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: hasGroups
              ? AnimatedBuilder(
                  animation: _tab,
                  builder: (_, __) {
                    final ids = widget.methodGroups[_methods[_tab.index]] ?? [];
                    return Column(children: [
                      TabBar(
                        controller: _tab,
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        tabs: _methods.map((m) =>
                            Tab(text: _methodTabLabels[m] ?? m)).toList(),
                        labelColor: scheme.primary,
                        unselectedLabelColor: scheme.onSurfaceVariant,
                        indicatorColor: scheme.primary,
                        dividerColor: tColor.withValues(alpha: 0.2),
                      ),
                      _PokemonList(ids: ids, onTap: widget.onTap),
                    ]);
                  },
                )
              : _PokemonList(ids: widget.fallbackIds, onTap: widget.onTap),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: scaffoldBg,
                border: Border.all(color: tColor, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('POKÉMON',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 0.8, color: tColor)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PokemonList extends StatelessWidget {
  final List<int>                            ids;
  final Future<void> Function(BuildContext, int) onTap;
  const _PokemonList({required this.ids, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (ids.isEmpty) return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Text('Nenhum Pokémon aprende este golpe por este método no jogo ativo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
    );
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: ids.map((id) => _PokemonTile(id: id, onTap: onTap)).toList(),
      ),
    );
  }
}

class _PokemonTile extends StatelessWidget {
  final int id;
  final Future<void> Function(BuildContext, int) onTap;
  const _PokemonTile({required this.id, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final svc    = PokedexDataService.instance;
    final name   = svc.getName(id);
    final types  = svc.getTypes(id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c1     = types.isNotEmpty ? typeColor(types[0]) : Colors.grey;
    final c2     = types.length > 1 ? typeColor(types[1]) : c1;

    return GestureDetector(
      onTap: () => onTap(context, id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: types.length > 1
              ? LinearGradient(colors: [
                  c1.withValues(alpha: isDark ? 0.18 : 0.12),
                  c2.withValues(alpha: isDark ? 0.18 : 0.12),
                ])
              : null,
          color: types.length <= 1
              ? c1.withValues(alpha: isDark ? 0.18 : 0.12) : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c1.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Row(children: [
          Image.asset('assets/sprites/artwork/$id.webp',
              width: 40, height: 40, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(width: 40, height: 40,
                  child: Icon(Icons.catching_pokemon, size: 22,
                      color: c1.withValues(alpha: 0.4)))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('#${id.toString().padLeft(3, '0')}',
                    style: TextStyle(fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6))),
                const SizedBox(width: 6),
                Text(name, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                for (final t in types) ...[
                  Image.asset(typeIconAsset(t), width: 18, height: 18,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(width: 18)),
                  const SizedBox(width: 4),
                ],
              ]),
            ],
          )),
          Icon(Icons.chevron_right, size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}
