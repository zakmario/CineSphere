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

/// Vrai si l'utilisateur a déjà vu le walkthrough de première utilisation.
/// Vérifie d'abord l'appareil (rapide, hors connexion) puis le profil Supabase
/// (pour ne pas le revoir après une réinstallation).
Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('cs_onboarding_done') ?? false) {
    return true;
  }
  final userId = SupaFlow.client.auth.currentUser?.id;
  if (userId == null) {
    return false;
  }
  try {
    final row = await SupaFlow.client
        .from('profiles')
        .select('onboarding_done')
        .eq('id', userId)
        .maybeSingle();
    final done = row?['onboarding_done'] == true;
    if (done) {
      await prefs.setBool('cs_onboarding_done', true);
    }
    return done;
  } catch (_) {
    return false;
  }
}
