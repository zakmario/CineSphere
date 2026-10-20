// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:shared_preferences/shared_preferences.dart';

/// Marque le walkthrough comme terminé et enregistre les genres préférés
/// (sur l'appareil et dans le profil Supabase si l'utilisateur est connecté).
Future completeOnboarding(List<String> favoriteGenres) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('cs_onboarding_done', true);
  await prefs.setStringList('cs_favorite_genres', favoriteGenres);

  final userId = SupaFlow.client.auth.currentUser?.id;
  if (userId == null) {
    return;
  }
  try {
    await SupaFlow.client.from('profiles').update({
      'onboarding_done': true,
      'favorite_genres': favoriteGenres,
    }).eq('id', userId);
  } catch (e) {
    // Les préférences restent enregistrées localement.
    debugPrint('completeOnboarding: $e');
  }
}
