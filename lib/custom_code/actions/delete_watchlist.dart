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

/// Supprime une liste du membre connecté et ses titres.
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> deleteWatchlist(String watchlistId) async {
  try {
    await CineFirebaseService.instance.deleteWatchlist(watchlistId);
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
