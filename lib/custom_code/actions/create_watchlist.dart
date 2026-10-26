// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/firestore_service.dart';

/// Crée une liste personnelle pour le membre connecté (onglet « Mes listes »).
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> createWatchlist(String name) async {
  try {
    await FirestoreService.instance.createWatchlist(name);
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
