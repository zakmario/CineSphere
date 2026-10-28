// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '/custom_code/actions/cine_local_db.dart';
import '/custom_code/actions/cine_notification_service.dart';
import '/custom_code/actions/cine_sync_service.dart';
import '/custom_code/actions/complete_onboarding.dart';
import '/custom_code/actions/firebase_service.dart';

/// Temps laissé aux modifications hors connexion pour partir avant la
/// déconnexion.
const Duration kLogoutSyncTimeout = Duration(seconds: 6);

/// Clés shared_preferences du membre effacées à la déconnexion. Gardées :
/// `cs_onboarding_done` et `cs_home_tour_done` (concernent l'appareil).
const kPrivatePreferenceKeys = [
  ...kNotificationPrivateKeys,
  kOnboardingPendingKey,
  kFavoriteGenreNamesKey,
];

/// Déconnexion (section 8) : à appeler AVANT *Log Out*, le membre doit
/// encore être connecté pour envoyer ses dernières modifications.
///
/// 1. envoie les modifications faites hors connexion (si le réseau répond) ;
/// 2. annule toutes les notifications programmées et oublie les rappels et
///    réglages gardés sur l'appareil ;
/// 3. vide les données privées SQLite (favoris, recherches, file
///    pending_sync) et les sections d'accueil personnalisées. Le cache
///    public (catalogue, calendrier) est gardé.
///
/// Renvoie le nombre de modifications perdues faute de réseau (0 en
/// général) : voir getPendingChangesCount pour prévenir le membre avant.
Future<int> clearPrivateLocalData() async {
  final local = CineLocalDb.instance;
  var lost = 0;

  if (local.isSupported) {
    try {
      // Compte supprimé ou déjà déconnecté : rien ne peut plus être envoyé.
      if (_signedIn() && await local.pendingCount() > 0) {
        final sync = CineSyncService.instance;
        if (await sync.checkConnection()) {
          await sync.syncNow().timeout(kLogoutSyncTimeout);
        }
      }
    } catch (e) {
      developer.log('envoi avant déconnexion', name: 'Logout', error: e);
    }
    try {
      lost = await local.pendingCount();
    } catch (_) {}
  }

  await CineNotificationService.instance.cancelAll();
  final prefs = await SharedPreferences.getInstance();
  for (final key in kPrivatePreferenceKeys) {
    await prefs.remove(key);
  }

  if (local.isSupported) {
    try {
      await local.clearPrivateData();
      await local.clearPersonalCache();
    } catch (e) {
      developer.log('SQLite', name: 'Logout', error: e);
    }
  }
  return lost;
}

bool _signedIn() {
  try {
    return CineFirebaseService.instance.currentUserId != null;
  } catch (_) {
    return false; // Firebase pas initialisé.
  }
}
