// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Marque un contenu comme vu, ou le retire des vus, pour l'utilisateur
/// connecté (table `watched`, membre 1). Retourne le nouvel état
/// (true = vu). Lève une exception si l'utilisateur n'est pas connecté.
Future<bool> toggleWatched(String mediaId) async {
  final userId = SupaFlow.client.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('Connectez-vous pour marquer un titre comme vu.');
  }
  final existing = await SupaFlow.client
      .from('watched')
      .select('id')
      .eq('user_id', userId)
      .eq('media_id', mediaId)
      .maybeSingle();
  if (existing != null) {
    await SupaFlow.client
        .from('watched')
        .delete()
        .eq('user_id', userId)
        .eq('media_id', mediaId);
    return false;
  }
  await SupaFlow.client
      .from('watched')
      .insert({'user_id': userId, 'media_id': mediaId});
  return true;
}
