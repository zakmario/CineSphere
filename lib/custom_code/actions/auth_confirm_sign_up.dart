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

/// Valide le code d'inscription reçu par e-mail (ce qui connecte le membre).
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> authConfirmSignUp(String email, String code) async {
  try {
    await AuthService.instance.confirmSignUp(email: email, code: code);
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
