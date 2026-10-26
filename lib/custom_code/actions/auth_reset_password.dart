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

/// Enregistre un nouveau mot de passe pour le membre connecté. Le mot de
/// passe oublié passe par le lien Firebase reçu par e-mail ; [email] et
/// [code] restent dans la signature pour les pages existantes.
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
    await AuthService.instance.changePassword(newPassword);
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
