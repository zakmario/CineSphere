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

/// Ajoute ou retire un contenu des favoris de l'utilisateur connecté.
/// Retourne le nouvel état (true = favori). Lève une exception si
/// l'utilisateur n'est pas connecté.
Future<bool> toggleFavorite(String mediaId) async {
  try {
    return await CineFirebaseService.instance.toggleFavorite(mediaId);
  } on CineFailure catch (failure) {
    throw Exception(failure.kind == CineFailureKind.unauthenticated
        ? 'Connectez-vous pour gérer vos favoris.'
        : failure.message);
  }
}
