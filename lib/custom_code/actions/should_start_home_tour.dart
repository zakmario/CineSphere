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

/// Vrai s'il faut lancer la visite guidée de la HomePage (Walkthrough
/// FlutterFlow) : walkthrough terminé et visite jamais faite sur cet
/// appareil. À tester au chargement de la HomePage avant *Start
/// Walkthrough*.
Future<bool> shouldStartHomeTour() =>
    OnboardingService.instance.shouldStartHomeTour();
