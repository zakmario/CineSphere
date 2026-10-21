// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/supabase_service.dart';

/// Renomme une liste du membre connecté (page Détail d'une liste).
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> renameWatchlist(String watchlistId, String name) async {
  try {
    await SupabaseService.instance.renameWatchlist(watchlistId, name);
    return '';
  } on CineFailure catch (failure) {
    return failure.message;
  }
}
