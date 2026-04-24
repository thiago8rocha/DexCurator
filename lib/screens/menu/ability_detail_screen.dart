import 'package:flutter/material.dart';
import 'package:dexcurator/models/pokemon.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show SectionCard, typeIconAsset, TypeBadge, bilingualModeNotifier;
import 'package:dexcurator/core/pokemon_types.dart' show typeColor;
import 'package:dexcurator/screens/detail/mainline_detail_screen.dart';
import 'package:dexcurator/screens/detail/nacional_detail_screen.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/translations.dart';
import 'package:dexcurator/screens/menu/abilities_list_screen.dart' show AbilityEntry;

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

class AbilityDetailSheet extends StatefulWidget {
  final AbilityEntry entry;
  const AbilityDetailSheet({super.key, required this.entry});
  @override State<AbilityDetailSheet> createState() => _AbilityDetailSheetState();
}

class _AbilityDetailSheetState extends State<AbilityDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  String _resolvedTitle(String mode) {
    final nameEn = _titleCase(widget.entry.nameEn.replaceAll('-', ' '));
    final namePt = translateAbility(widget.entry.nameEn);
    if (mode == 'pt') return namePt;
    return nameEn;
  }

  Future<void> _openPokemon(BuildContext ctx, int id) async {
    final svc     = PokedexDataService.instance;
    final poke    = Pokemon(
      id: id, entryNumber: id, name: svc.getName(id), types: svc.getTypes(id),
      baseHp: 0, baseAttack: 0, baseDefense: 0,
      baseSpAttack: 0, baseSpDefense: 0, baseSpeed: 0,
      spriteUrl:      'assets/sprites/artwork/$id.webp',
      spritePixelUrl: 'assets/sprites/pixel/$id.webp',
      spriteHomeUrl:  'assets/sprites/home/$id.webp',
    );
    final lastDex  = await StorageService().getLastPokedexId() ?? 'nacional';
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e      = widget.entry;

    return ValueListenableBuilder<String>(
      valueListenable: bilingualModeNotifier,
      builder: (ctx, mode, _) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
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

          // ── Nome da habilidade ──
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

              if (e.flavor.isNotEmpty) ...[
                SectionCard(
                  title: 'DESCRIÇÃO NO JOGO',
                  pokemonTypes: const [],
                  child: Text(e.flavor,
                      style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.5)),
                ),
                const SizedBox(height: 20),
              ],

              if (e.description.isNotEmpty) ...[
                SectionCard(
                  title: 'EFEITO',
                  pokemonTypes: const [],
                  child: Text(e.description,
                      style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.5)),
                ),
                const SizedBox(height: 20),
              ],

              if (e.effectLong.isNotEmpty && e.effectLong != e.description) ...[
                SectionCard(
                  title: 'EFEITO DETALHADO',
                  pokemonTypes: const [],
                  child: Text(e.effectLong,
                      style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.5)),
                ),
                const SizedBox(height: 20),
              ],

              _PokemonTabCard(tab: _tab, entry: e, onTap: _openPokemon),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── Card com abas de Pokémon ─────────────────────────────────────
class _PokemonTabCard extends StatelessWidget {
  final TabController tab;
  final AbilityEntry entry;
  final Future<void> Function(BuildContext, int) onTap;
  const _PokemonTabCard({required this.tab, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final tColor     = const Color(0xFF888888);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

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
          child: AnimatedBuilder(
            animation: tab,
            builder: (context, _) {
              final ids = tab.index == 0 ? entry.mainIds : entry.hiddenIds;
              return Column(children: [
                TabBar(
                  controller: tab,
                  tabs: const [Tab(text: 'Principal'), Tab(text: 'Oculta')],
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  dividerColor: tColor.withValues(alpha: 0.2),
                ),
                _PokemonList(ids: ids, onTap: onTap),
              ]);
            },
          ),
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

// ─── Lista de Pokémon ─────────────────────────────────────────────
class _PokemonList extends StatelessWidget {
  final List<int> ids;
  final Future<void> Function(BuildContext, int) onTap;
  const _PokemonList({required this.ids, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (ids.isEmpty) return Padding(
      padding: const EdgeInsets.all(12),
      child: Text('Nenhum Pokémon com esta habilidade.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
    );
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: ids.map((id) => _PokemonTile(id: id, onTap: onTap)).toList(),
      ),
    );
  }
}

// ─── Tile de Pokémon ──────────────────────────────────────────────
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
          color: types.length <= 1 ? c1.withValues(alpha: isDark ? 0.18 : 0.12) : null,
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('#${id.toString().padLeft(3, '0')}',
                  style: TextStyle(fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
              const SizedBox(width: 6),
              Text(name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              for (final t in types) ...[
                Image.asset(typeIconAsset(t), width: 18, height: 18, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 18)),
                const SizedBox(width: 4),
              ],
            ]),
          ])),
          Icon(Icons.chevron_right, size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}
