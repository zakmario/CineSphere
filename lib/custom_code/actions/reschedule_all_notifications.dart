// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/cine_notification_service.dart';

/// Reprogramme toutes les notifications avec les réglages actuels (heure,
/// veille / jour J, sorties, séries favorites, plateformes). Retourne le
/// nombre de notifications programmées.
Future<int> rescheduleAllNotifications() async {
  try {
    return await CineNotificationService.instance.rescheduleAll();
  } catch (e) {
    debugPrint('rescheduleAllNotifications: $e');
    return 0;
  }
}
