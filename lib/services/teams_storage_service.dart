import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PokemonTeam {
  final String    id;
  final String    gameId;
  final String    gameName;
  final String    name;
  final List<int> members;

  const PokemonTeam({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.name,
    required this.members,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'gameId': gameId, 'gameName': gameName,
    'name': name, 'members': members,
  };

  factory PokemonTeam.fromJson(Map<String, dynamic> j) => PokemonTeam(
    id:       j['id']       as String,
    gameId:   j['gameId']   as String,
    gameName: j['gameName'] as String,
    name:     j['name']     as String,
    members:  (j['members'] as List<dynamic>).cast<int>(),
  );

  PokemonTeam copyWith({String? name, List<int>? members}) => PokemonTeam(
    id: id, gameId: gameId, gameName: gameName,
    name:    name    ?? this.name,
    members: members ?? this.members,
  );
}

/// Persiste times localmente via SharedPreferences.
/// SharedPreferences cacheado após o primeiro acesso — mesmo padrão do StorageService.
class TeamsStorageService {
  static const _prefix    = 'team_';
  static const maxPerGame = 10;

  TeamsStorageService._();
  static final TeamsStorageService instance = TeamsStorageService._();

  static SharedPreferences? _prefs;
  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<PokemonTeam>> getAll() async {
    final prefs = await _instance;
    final keys  = prefs.getKeys()
        .where((k) => k.startsWith(_prefix))
        .toList()..sort();
    final out = <PokemonTeam>[];
    for (final k in keys) {
      try {
        final raw = prefs.getString(k);
        if (raw != null) out.add(PokemonTeam.fromJson(jsonDecode(raw)));
      } catch (_) {}
    }
    return out;
  }

  Future<List<PokemonTeam>> getByGame(String gameId) async =>
      (await getAll()).where((t) => t.gameId == gameId).toList();

  Future<bool> canSave(String gameId) async =>
      (await getByGame(gameId)).length < maxPerGame;

  Future<void> save(PokemonTeam team) async {
    final prefs = await _instance;
    await prefs.setString('$_prefix${team.id}', jsonEncode(team.toJson()));
  }

  Future<void> delete(String teamId) async {
    final prefs = await _instance;
    await prefs.remove('$_prefix$teamId');
  }

  static String newId() => DateTime.now().millisecondsSinceEpoch.toString();
}
