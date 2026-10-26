// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';

/// Marque le walkthrough comme terminé et enregistre les genres préférés
/// (sur l'appareil et dans le profil Firestore si l'utilisateur est connecté).
Future completeOnboarding(List<String> favoriteGenres) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('cs_onboarding_done', true);
  await prefs.setStringList('cs_favorite_genres', favoriteGenres);

  final userId = fb.FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    return;
  }
  try {
    // Le profil stocke les identifiants TMDB des genres choisis par nom.
    final genres = await FirebaseFirestore.instance.collection('genres').get();
    final ids = [
      for (final doc in genres.docs)
        if (favoriteGenres.contains(doc.data()['name'])) doc.data()['id'],
    ];
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'preferences.onboardingCompleted': true,
      'preferences.favoriteGenres': ids,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    // Les préférences restent enregistrées localement.
    debugPrint('completeOnboarding: $e');
  }
}
