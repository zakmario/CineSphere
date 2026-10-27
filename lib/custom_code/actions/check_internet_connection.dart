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

/// Vrai si Internet répond (interface active et serveurs joignables). Au
/// retour du réseau, les écritures en attente sont rejouées.
Future<bool> checkInternetConnection() async {
  final sync = CineSyncService.instance;
  await sync.start();
  return sync.checkConnection();
}
