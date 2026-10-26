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

/// Marque un contenu comme vu, ou le retire des vus, pour l'utilisateur
/// connecté (collection `watched`, membre 1). Retourne le nouvel état
/// (true = vu). Lève une exception si l'utilisateur n'est pas connecté.
Future<bool> toggleWatched(String mediaId) async {
  try {
    return await FirestoreService.instance.toggleWatched(mediaId);
  } on CineFailure catch (failure) {
    throw Exception(failure.kind == CineFailureKind.unauthenticated
        ? 'Connectez-vous pour marquer un titre comme vu.'
        : failure.message);
  }
}
