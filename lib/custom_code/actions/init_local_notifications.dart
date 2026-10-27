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

/// Initialise les notifications locales (canaux Android, fuseau horaire) et
/// demande la permission. Retourne true si l'application peut afficher des
/// notifications. À appeler depuis Paramètres ou avant un premier rappel.
Future<bool> initLocalNotifications() =>
    CineNotificationService.instance.init(requestPermission: true);
