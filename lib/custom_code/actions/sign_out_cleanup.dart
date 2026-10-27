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

import '/custom_code/actions/firebase_service.dart';

/// Données locales propres au membre connecté, effacées à la déconnexion.
/// L'onboarding (`cs_onboarding_done`) concerne l'appareil : il est gardé.
const kPrivateLocalKeys = ['cs_reminders', 'cs_favorite_genres'];

/// À appeler juste avant *Log Out* (section 8 : la déconnexion nettoie les
/// données privées et les notifications) : annule les rappels programmés et
/// efface les préférences locales du membre. Le cache SQLite du membre 3
/// s'ajoutera ici.
Future signOutCleanup() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in kPrivateLocalKeys) {
    // Sur le web, les rappels en attente vérifient cs_reminders avant de
    // s'afficher : vider la liste suffit à les annuler.
    await prefs.remove(key);
  }
  if (!kIsWeb) {
    try {
      await FlutterLocalNotificationsPlugin().cancelAll();
    } catch (e) {
      debugPrint('signOutCleanup: $e');
    }
  }
  CineFirebaseService.instance.invalidateCatalog();
}
