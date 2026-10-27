// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:shared_preferences/shared_preferences.dart';

import '/custom_code/actions/cine_notification_service.dart';

/// Programme une notification locale à [scheduledAt] (canal Rappels).
///
/// [reminderKey] identifie le rappel (ex. l'id de la sortie) : il sert à
/// l'annuler et à afficher l'état « rappel actif » des cloches. Retourne
/// false si la date est passée ou si la permission est refusée.
///
/// Pour un rappel à l'heure choisie dans les réglages, reprogrammé si elle
/// change, utiliser `CineNotificationService.scheduleReminder`
/// (ReleaseCalendar, bouton « Me prévenir »).
Future<bool> scheduleReleaseNotification(
  String reminderKey,
  String title,
  String body,
  DateTime scheduledAt,
) async {
  if (!scheduledAt.isAfter(DateTime.now())) {
    return false;
  }
  final service = CineNotificationService.instance;
  if (!await service.init(requestPermission: true)) {
    return false;
  }
  try {
    await service.notifier.schedule(
      id: notificationIdFromString(reminderKey),
      title: title,
      body: body,
      at: scheduledAt,
      channel: NotificationChannelKind.reminders,
    );
  } catch (e) {
    debugPrint('scheduleReleaseNotification: $e');
    return false;
  }
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getStringList(kRemindersKey) ?? <String>[];
  if (!keys.contains(reminderKey)) {
    await prefs.setStringList(kRemindersKey, [...keys, reminderKey]);
  }
  return true;
}
