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

/// « Tout marquer comme lu » : retourne le nombre de notifications
/// marquées (hors connexion, l'écriture attend le retour du réseau).
Future<int> markAllNotificationsRead() async {
  final service = CineNotificationService.instance;
  try {
    return await service.store.markAllRead(now: service.now());
  } catch (e) {
    debugPrint('markAllNotificationsRead: $e');
    return 0;
  }
}
