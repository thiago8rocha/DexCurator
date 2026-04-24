import 'package:flutter/material.dart';
import 'package:dexcurator/core/pokemon_types.dart';

/// Retrocompatibilidade — todos os dados reais estão em pokemon_types.dart.
/// Novos arquivos devem importar pokemon_types.dart diretamente.
class TypeColors {
  static Color fromType(String type) => typeColor(type);
  static Map<String, Color> get colors => typeColors;
}
