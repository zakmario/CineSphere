// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/cine_sync_service.dart';

/// Rejoue maintenant les écritures faites hors connexion (table
/// pending_sync), dans l'ordre, puis recopie les favoris dans SQLite.
/// Retourne le nombre d'opérations envoyées à Firestore.
Future<int> syncSqliteWithFirestore() async {
  try {
    return (await CineSyncService.instance.syncNow()).synced;
  } catch (e) {
    debugPrint('syncSqliteWithFirestore: $e');
    return 0;
  }
}
