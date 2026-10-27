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

/// Visite guidée de la HomePage terminée ou passée : elle ne sera plus
/// proposée (brancher sur *On Walkthrough Complete* et *On Walkthrough
/// Skip*).
Future markHomeTourDone() => OnboardingService.instance.markHomeTourDone();
