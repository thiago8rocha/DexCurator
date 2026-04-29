import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Provides in-game location data for all main-series games.
/// Data shape: { "speciesId": [ { location, game, games, method, rarity, levels, time_of_day?, weather? } ] }
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  Map<String, dynamic>? _data;
  Future<void>? _warmupFuture;

  static const _dexIdToGameId = <String, String>{
    'red___blue':                        'red-blue',
    'yellow':                            'yellow',
    'gold___silver':                     'gold-silver',
    'crystal':                           'crystal',
    'ruby___sapphire':                   'ruby-sapphire',
    'firered___leafgreen_(gba)':         'firered-leafgreen',
    'emerald':                           'emerald',
    'diamond___pearl':                   'diamond-pearl',
    'platinum':                          'platinum',
    'heartgold___soulsilver':            'heartgold-soulsilver',
    'black___white':                     'black-white',
    'black_2___white_2':                 'black-2-white-2',
    'x___y':                             'x-y',
    'omega_ruby___alpha_sapphire':       'omega-ruby-alpha-sapphire',
    'sun___moon':                        'sun-moon',
    'ultra_sun___ultra_moon':            'ultra-sun-ultra-moon',
    'lets_go_pikachu___eevee':           'lets-go-pikachu-eevee',
    'sword___shield':                    'sword-shield',
    'brilliant_diamond___shining_pearl': 'brilliant-diamond-shining-pearl',
    'legends_arceus':                    'legends-arceus',
    'scarlet___violet':                  'scarlet-violet',
    'legends_z-a':                       'legends-z-a',
  };

  /// Safe to call concurrently — all callers share the same Future.
  Future<void> warmup() {
    _warmupFuture ??= _doWarmup();
    return _warmupFuture!;
  }

  Future<void> _doWarmup() async {
    final raw = await rootBundle.loadString('assets/locations.json');
    if (kDebugMode) {
      _data = json.decode(raw) as Map<String, dynamic>;
    } else {
      _data = await compute<String, Map<String, dynamic>>(
        (s) => json.decode(s) as Map<String, dynamic>,
        raw,
      );
    }
  }

  static String _timeOfDayString(dynamic timeOfDay) {
    if (timeOfDay == null) return '';
    final list = (timeOfDay as List<dynamic>).cast<String>();
    if (list.isEmpty) return '';
    final has = list.toSet();
    if (has.containsAll({'morning', 'day', 'night'})) return '';
    if (has.contains('morning') && has.contains('day') && !has.contains('night')) return 'Dia';
    if (has.contains('morning') && !has.contains('day') && has.contains('night')) return 'Manhã e Noite';
    if (list.length == 1) {
      switch (list.first) {
        case 'morning': return 'Manhã';
        case 'day':     return 'Dia';
        case 'night':   return 'Noite';
      }
    }
    return list.join(', ');
  }

  static String _weatherString(String weather) {
    if (weather.isEmpty || weather == 'All Weather') return '';
    return weather;
  }

  /// Returns locations for a species in a specific dex/game.
  /// Each entry has: location, games (List<String>), method, levels, rarity, time, weather
  List<Map<String, dynamic>> getLocations(int speciesId, String dexId) {
    if (_data == null) return [];
    final gameId = _dexIdToGameId[dexId];
    if (gameId == null) return [];
    final raw = _data![speciesId.toString()] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .cast<Map<String, dynamic>>()
        .where((e) => e['game'] == gameId)
        .map((e) => {
              'location': e['location'] as String? ?? '',
              'games':    (e['games'] as List<dynamic>?)?.cast<String>() ?? <String>[],
              'method':   e['method'] as String? ?? '',
              'levels':   e['levels'] as String? ?? '',
              'rarity':   e['rarity'] as String? ?? '',
              'time':     _timeOfDayString(e['time_of_day']),
              'weather':  _weatherString(e['weather'] as String? ?? ''),
            })
        .toList();
  }

  /// Returns all dexIds that have location data for a species.
  List<String> getAvailableDexIds(int speciesId) {
    if (_data == null) return [];
    final raw = _data![speciesId.toString()] as List<dynamic>?;
    if (raw == null) return [];
    final gameIds = raw
        .cast<Map<String, dynamic>>()
        .map((e) => e['game'] as String? ?? '')
        .where((g) => g.isNotEmpty)
        .toSet();
    final reverse = {for (final e in _dexIdToGameId.entries) e.value: e.key};
    return gameIds.map((g) => reverse[g]).whereType<String>().toList();
  }

  bool get isLoaded => _data != null;
}
