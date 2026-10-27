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

/// « Vider le cache » : supprime les titres, sections de l'accueil et
/// sorties gardés dans SQLite (pas les favoris ni les écritures en attente).
/// Retourne le message à afficher, ex. « Cache vidé : 1,2 Mo libérés ».
Future<String> clearLocalCache() async {
  final local = CineLocalDb.instance;
  if (!local.isSupported) {
    return 'Pas de cache local sur le web.';
  }
  try {
    final freed = await local.clearCache();
    return 'Cache vidé : ${formatBytes(freed)} libérés';
  } catch (e) {
    debugPrint('clearLocalCache: $e');
    return 'Impossible de vider le cache.';
  }
}
