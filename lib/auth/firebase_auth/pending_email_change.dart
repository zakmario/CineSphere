import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';

final _emailChangesInFlight = <String>{};
int _emailChangeSequence = 0;
String _pendingEmailKey(String uid) => 'ff_pending_email_change_$uid';

// Persist only a successful, explicitly requested email change. Auth success
// must not depend on local persistence or on a Firestore acknowledgement.
Future<void> rememberPendingEmailChange(String uid, String email) async {
  final request = jsonEncode({
    'email': email.trim(),
    'requestId':
        '${DateTime.now().microsecondsSinceEpoch}-${_emailChangeSequence++}',
  });
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingEmailKey(uid), request);
  } catch (e) {
    print('Could not remember the requested email change: $e');
  }
}

// Called without awaiting it after sign-in/restoration and explicit refresh.
// An unrelated Auth/profile mismatch is never a reason to write a document.
Future<void> syncPendingEmailChange(User? user) async {
  if (user == null || !_emailChangesInFlight.add(user.uid)) return;
  final uid = user.uid;
  final key = _pendingEmailKey(uid);
  SharedPreferences? preferences;
  String? request;
  try {
    preferences = await SharedPreferences.getInstance();
    request = preferences.getString(key);
    if (request == null) return;
    final target =
        (jsonDecode(request) as Map<String, dynamic>)['email'] as String;
    final current = FirebaseAuth.instance.currentUser;
    if (current == null ||
        current.uid != uid ||
        !current.emailVerified ||
        target.isEmpty ||
        current.email?.toLowerCase() != target.toLowerCase()) {
      return;
    }

    // Capture the verified account's reference, not a possibly stale global
    // user document. update() never recreates a deleted user document.
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'email': current.email});
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
    // A newer request, even for the same target, owns its own acknowledgement.
    if (preferences.getString(key) == request) {
      await preferences.remove(key);
    }
  } catch (e) {
    // Keep the request for the next sign-in/refresh after a transient failure.
    print('Could not sync the requested email change: $e');
  } finally {
    _emailChangesInFlight.remove(uid);
    // A replacement request may have arrived while a previous write waited
    // for the server. Retry that request without blocking any Auth operation.
    if (request != null &&
        preferences?.getString(key) != null &&
        preferences?.getString(key) != request) {
      final current = FirebaseAuth.instance.currentUser;
      if (current?.uid == uid) unawaited(syncPendingEmailChange(current));
    }
  }
}
