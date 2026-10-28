// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/cine_local_db.dart';

/// Nombre de modifications faites hors connexion pas encore envoyées
/// (favoris…). Avant *Log Out* : si > 0 et hors connexion, prévenir le
/// membre qu'elles seront perdues. Toujours 0 sur le web.
Future<int> getPendingChangesCount() async {
  final local = CineLocalDb.instance;
  if (!local.isSupported) {
    return 0;
  }
  try {
    return await local.pendingCount();
  } catch (_) {
    return 0;
  }
}
