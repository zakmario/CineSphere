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
import '/custom_code/actions/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Connexion par e-mail et mot de passe, pour le bouton « Se connecter ».
///
/// Retourne "" si le membre est connecté, [kAuthNeedsCode] si son adresse
/// n'est pas encore confirmée (il reste connecté pour pouvoir renvoyer le
/// lien depuis la page ConfirmationEmail), sinon le message d'erreur.
Future<String> authSignIn(String email, String password) async {
  try {
    await AuthService.instance.signIn(email: email, password: password);
    return '';
  } on CineFailure catch (failure) {
    final cause = failure.cause;
    if (cause is fb.FirebaseAuthException &&
        cause.code == 'email-not-verified') {
      return kAuthNeedsCode;
    }
    return failure.message;
  }
}
