// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/auth_service.dart';
import '/custom_code/actions/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Connexion par e-mail et mot de passe, pour le bouton « Se connecter ».
///
/// Retourne "" si le membre est connecté, [kAuthNeedsCode] si son adresse
/// n'est pas encore confirmée (un nouveau code vient de lui être envoyé),
/// sinon le message d'erreur à afficher.
Future<String> authSignIn(String email, String password) async {
  try {
    await AuthService.instance.signIn(email: email, password: password);
    return '';
  } on CineFailure catch (failure) {
    final cause = failure.cause;
    if (cause is supa.AuthException &&
        authErrorCode(cause) == 'email_not_confirmed') {
      try {
        await AuthService.instance.resendSignUpCode(email);
      } on CineFailure catch (resendFailure) {
        return resendFailure.message;
      }
      return kAuthNeedsCode;
    }
    return failure.message;
  }
}
