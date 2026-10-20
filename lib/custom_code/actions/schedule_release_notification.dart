// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Programme une notification locale pour une sortie (film / épisode).
///
/// [reminderKey] identifie le rappel (ex. l'id du release_event) : il sert à
/// l'annuler et à afficher l'état "rappel actif" dans l'interface.
/// Retourne false si la date est passée ou si la permission est refusée.
///
/// Sur le web (mode Test de FlutterFlow), le navigateur ne sait pas programmer
/// de notification : on l'affiche à l'heure prévue tant que l'onglet est ouvert.
Future<bool> scheduleReleaseNotification(
  String reminderKey,
  String title,
  String body,
  DateTime scheduledAt,
) async {
  if (!scheduledAt.isAfter(DateTime.now())) {
    return false;
  }
  if (!await initLocalNotifications()) {
    return false;
  }

  try {
    if (kIsWeb) {
      Timer(scheduledAt.difference(DateTime.now()), () async {
        // Le rappel a pu être annulé entre-temps.
        if ((await getScheduledReminders()).contains(reminderKey)) {
          await showInstantNotification(title, body);
          await cancelReleaseNotification(reminderKey);
        }
      });
    } else {
      await FlutterLocalNotificationsPlugin().zonedSchedule(
        id: notificationIdFromString(reminderKey),
        title: title,
        body: body,
        payload: reminderKey,
        scheduledDate: tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'cinesphere_releases',
            'Sorties',
            channelDescription: "Rappels de sorties de films et d'épisodes",
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  } catch (e) {
    debugPrint('scheduleReleaseNotification: $e');
    return false;
  }

  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getStringList('cs_reminders') ?? <String>[];
  if (!keys.contains(reminderKey)) {
    await prefs.setStringList('cs_reminders', [...keys, reminderKey]);
  }
  return true;
}
