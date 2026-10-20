// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Affiche immédiatement une notification locale (démo / bouton de test dans
/// les Paramètres). Fonctionne aussi sur le web si la permission est donnée.
Future<bool> showInstantNotification(
  String title,
  String body,
) async {
  if (!await initLocalNotifications()) {
    return false;
  }
  try {
    await FlutterLocalNotificationsPlugin().show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cinesphere_general',
          'Général',
          channelDescription: 'Notifications générales de CineSphere',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    return true;
  } catch (e) {
    debugPrint('showInstantNotification: $e');
    return false;
  }
}
