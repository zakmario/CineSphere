// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/firebase_service.dart';

/// Retire un titre ([itemId] = clé movie_550) d'une liste (page Détail
/// d'une liste). Retourne "" en cas de succès, sinon le message d'erreur.
Future<String> removeWatchlistItem(String watchlistId, String itemId) async {
  try {
    await CineFirebaseService.instance.removeWatchlistItem(watchlistId, itemId);
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
