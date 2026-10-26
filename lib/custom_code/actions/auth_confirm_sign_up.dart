// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/auth_service.dart';
import '/custom_code/actions/firebase_service.dart';

/// Vérifie que le membre a cliqué sur le lien de confirmation reçu par
/// e-mail. [email] et [code] restent dans la signature pour la page :
/// Firebase confirme par lien, pas par code.
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> authConfirmSignUp(String email, String code) async {
  try {
    await AuthService.instance.confirmSignUp();
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
