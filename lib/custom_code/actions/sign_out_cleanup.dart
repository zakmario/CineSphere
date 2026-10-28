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

import '/custom_code/actions/clear_private_local_data.dart';
import '/custom_code/actions/firebase_service.dart';

/// Données locales propres au membre connecté, effacées à la déconnexion.
/// L'onboarding (`cs_onboarding_done`) concerne l'appareil : il est gardé.
const kPrivateLocalKeys = ['cs_reminders', 'cs_favorite_genres'];

/// À appeler juste avant *Log Out* et après la suppression du compte
/// (section 8 : la déconnexion nettoie les données privées et les
/// notifications). [clearPrivateLocalData] (membre 3) envoie les
/// modifications faites hors connexion, annule les notifications et vide le
/// cache SQLite privé ; puis les préférences locales du membre sont
/// effacées et le catalogue en mémoire oublié.
Future signOutCleanup() async {
  await clearPrivateLocalData();
  final prefs = await SharedPreferences.getInstance();
  for (final key in kPrivateLocalKeys) {
    await prefs.remove(key);
  }
  CineFirebaseService.instance.invalidateCatalog();
}
