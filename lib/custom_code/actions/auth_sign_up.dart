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

/// Création de compte, pour le bouton « Créer mon compte ».
///
/// Retourne "" si le membre est connecté, [kAuthNeedsCode] s'il doit
/// confirmer son adresse avec le lien reçu par e-mail, sinon le message
/// d'erreur à afficher.
Future<String> authSignUp(
  String username,
  String email,
  String password,
  String confirmPassword,
) async {
  final mismatch = validatePasswordConfirmation(password, confirmPassword);
  if (mismatch != null) {
    return mismatch;
  }
  try {
    final outcome = await AuthService.instance
        .signUp(username: username, email: email, password: password);
    return outcome == SignUpOutcome.signedIn ? '' : kAuthNeedsCode;
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
