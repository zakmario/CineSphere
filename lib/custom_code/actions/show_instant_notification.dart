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

/// Affiche immédiatement une notification locale (bouton de test dans les
/// Paramètres). Fonctionne aussi sur le web si la permission est donnée.
Future<bool> showInstantNotification(
  String title,
  String body,
) =>
    CineNotificationService.instance.showNow(title, body);
