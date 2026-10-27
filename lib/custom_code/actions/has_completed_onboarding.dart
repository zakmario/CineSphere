// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/complete_onboarding.dart';

/// Vrai si l'utilisateur a déjà vu le walkthrough de première utilisation.
/// Vérifie d'abord l'appareil (rapide, hors connexion) puis le profil
/// Firestore (pour ne pas le revoir après une réinstallation).
Future<bool> hasCompletedOnboarding() =>
    OnboardingService.instance.isCompleted();
