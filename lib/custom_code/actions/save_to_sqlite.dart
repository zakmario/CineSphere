// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/cine_local_db.dart';
import '/custom_code/actions/firebase_service.dart';

/// Met un contenu en cache dans SQLite pour l'affichage hors connexion.
///
/// - [table] `cached_movies` / `cached_series` : [json] = un titre (ligne du
///   catalogue), [key] = sa clé `movie_550` ou son identifiant TMDB ;
/// - [table] `cached_home_sections` : [json] = liste de titres, [key] = nom
///   de la section (`trending`, `upcoming`…) ;
/// - [table] `calendar_events` : [json] = liste de sorties.
///
/// Retourne false si la table est inconnue, les données invalides ou sur le
/// web (pas de SQLite).
Future<bool> saveToSqlite(
  String table,
  String key,
  dynamic json,
) async {
  final local = CineLocalDb.instance;
  if (!local.isSupported || json == null) {
    return false;
  }
  List<Map<String, dynamic>> rows() => [
        for (final item in json is List ? json : [json])
          if (item is Map) Map<String, dynamic>.from(item),
      ];
  try {
    switch (table) {
      case 'cached_movies':
      case 'cached_series':
        if (json is! Map) {
          return false;
        }
        final type = table == 'cached_series' ? 'series' : 'movie';
        final row = Map<String, dynamic>.from(json);
        final id = parseMediaKey(key) != null
            ? key
            : mediaKey(type, int.tryParse(key) ?? -1);
        if (parseMediaKey(id) == null) {
          return false;
        }
        await local.saveCatalog([
          row
            ..['id'] = id
            ..['media_type'] = type,
        ]);
        return true;
      case 'cached_home_sections':
        await local.saveHomeSection(key, rows());
        return true;
      case 'calendar_events':
        await local.saveCalendarEvents(rows());
        return true;
    }
  } catch (e) {
    debugPrint('saveToSqlite: $e');
  }
  return false;
}
