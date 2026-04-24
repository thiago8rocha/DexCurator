import 'package:flutter/material.dart';

/// Fonte única de verdade para todos os dados de tipos Pokémon.
///
/// I18N: Para adicionar um novo idioma, crie um novo mapa seguindo o
/// padrão de [typeNamesEn] e [typeNamesPt] e troque a função [typeName]
/// para retornar o mapa correto baseado no locale. Nenhum outro arquivo
/// precisará ser alterado.
///
/// USO:
///   typeName('fire')         → 'Fogo'  (usa PT por padrão)
///   typeColor('fire')        → Color(...)
///   typeEffectiveness['fire'] → {...}
///
/// TCG Pocket usa nomes diferentes — ver [tcgTypeName].

// ─── LISTA CANÔNICA DE TIPOS ──────────────────────────────────────

/// Todos os 18 tipos em ordem, chave lowercase da PokéAPI.
const List<String> kAllTypes = [
  'normal', 'fire', 'water', 'electric', 'grass', 'ice',
  'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug',
  'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy',
];

// ─── NOMES PT-BR (jogos principais) ──────────────────────────────

/// Mapa EN → PT-BR para exibição nos jogos principais.
/// Baseado nos nomes oficiais usados no Brasil pela The Pokémon Company.
const Map<String, String> typeNamesPt = {
  'normal':   'Normal',
  'fire':     'Fogo',
  'water':    'Água',
  'electric': 'Elétrico',
  'grass':    'Planta',
  'ice':      'Gelo',
  'fighting': 'Lutador',
  'poison':   'Venenoso',
  'ground':   'Terrestre',
  'flying':   'Voador',
  'psychic':  'Psíquico',
  'bug':      'Inseto',
  'rock':     'Pedra',
  'ghost':    'Fantasma',
  'dragon':   'Dragão',
  'dark':     'Sombrio',
  'steel':    'Aço',
  'fairy':    'Fada',
};

/// Mapa EN → EN (para modo bilíngue ou fallback).
const Map<String, String> typeNamesEn = {
  'normal':   'Normal',
  'fire':     'Fire',
  'water':    'Water',
  'electric': 'Electric',
  'grass':    'Grass',
  'ice':      'Ice',
  'fighting': 'Fighting',
  'poison':   'Poison',
  'ground':   'Ground',
  'flying':   'Flying',
  'psychic':  'Psychic',
  'bug':      'Bug',
  'rock':     'Rock',
  'ghost':    'Ghost',
  'dragon':   'Dragon',
  'dark':     'Dark',
  'steel':    'Steel',
  'fairy':    'Fairy',
};

/// Retorna o nome PT-BR do tipo. Fallback para a chave EN se não encontrado.
String typeName(String typeKey) =>
    typeNamesPt[typeKey.toLowerCase()] ?? typeKey;

/// Retorna o nome EN do tipo. Fallback para a chave se não encontrado.
String typeNameEn(String typeKey) =>
    typeNamesEn[typeKey.toLowerCase()] ?? typeKey;

// ─── NOMES TCG POCKET ─────────────────────────────────────────────

/// Nomes dos tipos de energia no TCG Pocket (PT-BR).
/// São diferentes dos jogos principais — ex: 'Elétrico' vira 'Raios'.
const Map<String, String> tcgTypeNamesPt = {
  'Grass':      'Planta',
  'Fire':       'Fogo',
  'Water':      'Água',
  'Lightning':  'Raios',
  'Psychic':    'Psíquico',
  'Fighting':   'Luta',
  'Darkness':   'Escuridão',
  'Metal':      'Metal',
  'Dragon':     'Dragão',
  'Colorless':  'Incolor',
};

/// Retorna o nome PT-BR do tipo de energia TCG Pocket.
String tcgTypeName(String tcgKey) =>
    tcgTypeNamesPt[tcgKey] ?? tcgKey;

// ─── CORES DE TIPO ────────────────────────────────────────────────

/// Cores oficiais por tipo (chave lowercase da PokéAPI).
/// Usada em badges, barras, backgrounds e qualquer elemento visual de tipo.
const Map<String, Color> typeColors = {
  'normal':   Color.fromRGBO(144, 153, 161, 1),
  'fire':     Color.fromRGBO(255, 159,  90, 1),
  'water':    Color.fromRGBO( 77, 144, 213, 1),
  'grass':    Color.fromRGBO(104, 189,  96, 1),
  'electric': Color.fromRGBO(243, 210,  59, 1),
  'ice':      Color.fromRGBO(118, 206, 193, 1),
  'fighting': Color.fromRGBO(207,  68, 108, 1),
  'poison':   Color.fromRGBO(171, 107, 200, 1),
  'ground':   Color.fromRGBO(217, 121,  73, 1),
  'flying':   Color.fromRGBO(148, 171, 222, 1),
  'psychic':  Color.fromRGBO(249, 113, 118, 1),
  'bug':      Color.fromRGBO(144, 193,  45, 1),
  'rock':     Color.fromRGBO(199, 183, 139, 1),
  'ghost':    Color.fromRGBO( 82, 105, 172, 1),
  'dragon':   Color.fromRGBO(  9, 109, 196, 1),
  'dark':     Color.fromRGBO( 95,  88, 106, 1),
  'steel':    Color.fromRGBO( 92, 143, 162, 1),
  'fairy':    Color.fromRGBO(236, 144, 230, 1),
};

/// Retorna a cor do tipo. Fallback para cinza neutro se não encontrado.
Color typeColor(String typeKey) =>
    typeColors[typeKey.toLowerCase()] ?? const Color(0xFF9E9E9E);

/// Retorna branco ou preto dependendo da luminância do fundo do tipo.
Color typeTextColor(Color bg) =>
    bg.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;

// ─── EFETIVIDADE DE TIPOS ─────────────────────────────────────────

/// Tabela completa de efetividade ofensiva.
/// Formato: typeEffectiveness[atacante][defensor] → multiplicador
/// Valores: 2.0 (super efetivo), 0.5 (não muito efetivo), 0.0 (imune)
/// Ausência de entrada = 1.0 (dano normal)
const Map<String, Map<String, double>> typeEffectiveness = {
  'normal':   {'fighting': 2.0, 'ghost': 0.0},
  'fire':     {'water': 2.0, 'rock': 2.0, 'ground': 2.0, 'fire': 0.5, 'grass': 0.5, 'ice': 0.5, 'bug': 0.5, 'steel': 0.5, 'fairy': 0.5},
  'water':    {'electric': 2.0, 'grass': 2.0, 'fire': 0.5, 'water': 0.5, 'ice': 0.5, 'steel': 0.5},
  'electric': {'ground': 2.0, 'electric': 0.5, 'flying': 0.5, 'steel': 0.5},
  'grass':    {'fire': 2.0, 'ice': 2.0, 'poison': 2.0, 'flying': 2.0, 'bug': 2.0, 'water': 0.5, 'electric': 0.5, 'grass': 0.5, 'ground': 0.5},
  'ice':      {'fire': 2.0, 'fighting': 2.0, 'rock': 2.0, 'steel': 2.0, 'ice': 0.5},
  'fighting': {'flying': 2.0, 'psychic': 2.0, 'fairy': 2.0, 'rock': 0.5, 'bug': 0.5, 'dark': 0.5},
  'poison':   {'ground': 2.0, 'psychic': 2.0, 'fighting': 0.5, 'poison': 0.5, 'bug': 0.5, 'grass': 0.5, 'fairy': 0.5},
  'ground':   {'water': 2.0, 'grass': 2.0, 'ice': 2.0, 'electric': 0.0, 'poison': 0.5, 'rock': 0.5},
  'flying':   {'electric': 2.0, 'ice': 2.0, 'rock': 2.0, 'ground': 0.0, 'fighting': 0.5, 'bug': 0.5, 'grass': 0.5},
  'psychic':  {'bug': 2.0, 'ghost': 2.0, 'dark': 2.0, 'fighting': 0.5, 'psychic': 0.5},
  'bug':      {'fire': 2.0, 'flying': 2.0, 'rock': 2.0, 'fighting': 0.5, 'ground': 0.5, 'grass': 0.5},
  'rock':     {'water': 2.0, 'grass': 2.0, 'fighting': 2.0, 'ground': 2.0, 'steel': 2.0, 'normal': 0.5, 'fire': 0.5, 'poison': 0.5, 'flying': 0.5},
  'ghost':    {'ghost': 2.0, 'dark': 2.0, 'normal': 0.0, 'fighting': 0.0, 'poison': 0.5, 'bug': 0.5},
  'dragon':   {'ice': 2.0, 'dragon': 2.0, 'fairy': 2.0, 'fire': 0.5, 'water': 0.5, 'electric': 0.5, 'grass': 0.5},
  'dark':     {'fighting': 2.0, 'bug': 2.0, 'fairy': 2.0, 'ghost': 0.5, 'dark': 0.5, 'psychic': 0.0},
  'steel':    {'fire': 2.0, 'fighting': 2.0, 'ground': 2.0, 'normal': 0.5, 'grass': 0.5, 'ice': 0.5, 'flying': 0.5, 'psychic': 0.5, 'bug': 0.5, 'rock': 0.5, 'dragon': 0.5, 'steel': 0.5, 'fairy': 0.5, 'poison': 0.0},
  'fairy':    {'poison': 2.0, 'steel': 2.0, 'fighting': 0.5, 'bug': 0.5, 'dark': 0.5, 'dragon': 0.0},
};

// ─── CLASSE TYPECOLORS (RETROCOMPATIBILIDADE) ─────────────────────
// Mantida para não quebrar arquivos que ainda importam TypeColors.
// Novos arquivos devem usar typeColor() diretamente.

class TypeColors {
  /// Use typeColor() diretamente em código novo.
  static Color fromType(String type) => typeColor(type);

  /// Use typeColors diretamente em código novo.
  static const Map<String, Color> colors = typeColors;
}
