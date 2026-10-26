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

/// Ajoute un titre du catalogue (mediaId) à une liste (bouton de la fiche).
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> addToWatchlist(String watchlistId, String mediaId) async {
  try {
    await CineFirebaseService.instance.addMediaToWatchlist(watchlistId, mediaId);
    return '';
  } on CineFailure catch (failure) {
    return failure.kind == CineFailureKind.conflict
        ? 'Ce titre est déjà dans la liste.'
        : failure.message;
  }
}
