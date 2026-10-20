// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Ajoute ou retire un contenu des favoris de l'utilisateur connecté.
/// Retourne le nouvel état (true = favori). Lève une exception si
/// l'utilisateur n'est pas connecté.
Future<bool> toggleFavorite(String mediaId) async {
  final userId = SupaFlow.client.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('Connectez-vous pour gérer vos favoris.');
  }
  final existing = await SupaFlow.client
      .from('favorites')
      .select('media_id')
      .eq('user_id', userId)
      .eq('media_id', mediaId)
      .maybeSingle();
  if (existing != null) {
    await SupaFlow.client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('media_id', mediaId);
    return false;
  }
  await SupaFlow.client
      .from('favorites')
      .insert({'user_id': userId, 'media_id': mediaId});
  return true;
}
