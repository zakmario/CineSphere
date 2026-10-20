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

/// Vérifie le code de réinitialisation puis enregistre le nouveau mot de
/// passe (le membre est alors connecté).
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> authResetPassword(
  String email,
  String code,
  String newPassword,
  String confirmPassword,
) async {
  final mismatch = validatePasswordConfirmation(newPassword, confirmPassword);
  if (mismatch != null) {
    return mismatch;
  }
  try {
    await AuthService.instance
        .resetPassword(email: email, code: code, newPassword: newPassword);
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
