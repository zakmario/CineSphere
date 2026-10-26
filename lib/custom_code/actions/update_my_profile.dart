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

/// Enregistre le pseudo et la bio du membre connecté (page Profil).
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> updateMyProfile(String username, String bio) async {
  final service = CineFirebaseService.instance;
  try {
    if (!await service.isUsernameAvailable(username)) {
      return 'Ce pseudo est déjà utilisé.';
    }
    await service.updateProfile(username: username, bio: bio);
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
