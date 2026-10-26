// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Annule un rappel programmé avec scheduleReleaseNotification.
Future cancelReleaseNotification(String reminderKey) async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getStringList('cs_reminders') ?? <String>[];
  await prefs.setStringList(
    'cs_reminders',
    keys.where((k) => k != reminderKey).toList(),
  );
  if (kIsWeb) {
    // Le Timer web vérifie la liste ci-dessus avant d'afficher quoi que ce soit.
    return;
  }
  try {
    await FlutterLocalNotificationsPlugin()
        .cancel(id: notificationIdFromString(reminderKey));
  } catch (e) {
    debugPrint('cancelReleaseNotification: $e');
  }
}
