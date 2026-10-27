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

/// Nombre de notifications remises et non lues (badge).
Future<int> getUnreadNotificationsCount() async {
  final service = CineNotificationService.instance;
  try {
    final unread = await service.store.watchUnread().first;
    return unread.where((n) => n.isDue(service.now())).length;
  } catch (e) {
    debugPrint('getUnreadNotificationsCount: $e');
    return 0;
  }
}
