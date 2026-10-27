// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '/custom_code/actions/cine_local_db.dart';
import '/custom_code/actions/firebase_service.dart';

/// Synchronisation hors connexion (cahier des charges, section 6.10).
///
/// Action FlutterFlow d'ancrage : démarre l'écoute du réseau (une seule
/// fois) et renvoie l'état de la connexion. `OfflineBanner` et
/// `OfflineScreen` la démarrent aussi d'eux-mêmes.
Future<bool> cineSyncService() async {
  await CineSyncService.instance.start();
  return CineSyncService.instance.isOnline;
}

/// Essais d'envoi d'une opération refusée par Firestore avant abandon.
const int kMaxSyncRetries = 5;

/// Délai d'une écriture Firestore pendant la synchronisation.
const Duration kSyncTimeout = Duration(seconds: 15);

// État du réseau -----------------------------------------------------------

/// Source de l'état du réseau (remplacée dans les tests).
abstract class NetworkStatus {
  Future<bool> isOnline();

  /// Émet à chaque changement de connexion.
  Stream<bool> get changes;
}

/// connectivity_plus indique seulement l'interface active (Wi-Fi, données
/// mobiles…) : sur téléphone, on vérifie en plus que les serveurs Google
/// répondent (Wi-Fi sans Internet, portail captif). Sur le web, le
/// navigateur fait foi.
class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasInterface(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> _reachable(List<ConnectivityResult> results) async {
    if (!_hasInterface(results)) {
      return false;
    }
    if (kIsWeb) {
      return true;
    }
    try {
      // Toute réponse HTTP (même 404) prouve que le réseau passe.
      await http
          .head(Uri.parse('https://firestore.googleapis.com/'))
          .timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isOnline() async {
    try {
      return await _reachable(await _connectivity.checkConnectivity());
    } catch (error) {
      // Plugin absent : on laisse Firestore décider.
      developer.log('isOnline', name: 'CineSyncService', error: error);
      return true;
    }
  }

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.asyncMap(_reachable);
}

// Rapport de synchronisation --------------------------------------------

enum SyncEventKind {
  /// Une écriture a été mise en file (hors connexion).
  queued,

  /// Une synchronisation vient de se terminer : les écrans se rafraîchissent.
  synced,
}

class SyncEvent {
  const SyncEvent(
    this.kind, {
    this.synced = 0,
    this.failed = 0,
    this.dropped = 0,
    this.remaining = 0,
    this.interrupted = false,
  });

  final SyncEventKind kind;

  /// Opérations envoyées à Firestore.
  final int synced;

  /// Refusées, gardées pour un nouvel essai.
  final int failed;

  /// Refusées [kMaxSyncRetries] fois : abandonnées.
  final int dropped;

  /// Encore en file pour le membre connecté.
  final int remaining;

  /// Réseau perdu pendant l'envoi : la suite attend la prochaine connexion.
  final bool interrupted;

  @override
  String toString() => 'SyncEvent(${kind.name}, synced: $synced, '
      'failed: $failed, dropped: $dropped, remaining: $remaining)';
}

/// Envoie une opération à Firestore.
typedef RemoteWriter = Future<void> Function(PendingSyncOperation operation);

/// Favoris Firestore du membre (lignes [cineRow]).
typedef FavoritesFetcher = Future<List<Map<String, dynamic>>> Function();

// Service ---------------------------------------------------------------

/// Écoute le réseau, met en file les écritures faites hors connexion et les
/// rejoue au retour du réseau, dans l'ordre (dernière écriture gagnante :
/// voir [CineLocalDb.enqueuePending]), puis émet [SyncEventKind.synced].
///
/// Les opérations rejouées sont idempotentes (set, update de valeurs,
/// delete) : renvoyer une écriture déjà reçue par Firestore ne change rien.
class CineSyncService {
  CineSyncService({
    CineLocalDb? local,
    CineFirebaseService? remote,
    NetworkStatus? network,
    RemoteWriter? writer,
    FavoritesFetcher? fetchFavorites,
  })  : _local = local,
        _remote = remote,
        _network = network,
        _writer = writer,
        _fetchFavorites = fetchFavorites;

  static CineSyncService? _instance;
  static CineSyncService? _override;

  static CineSyncService get instance =>
      _override ?? (_instance ??= CineSyncService());

  /// Remplace le service partagé (tests). `null` rétablit le vrai service.
  @visibleForTesting
  static set debugInstance(CineSyncService? service) => _override = service;

  final CineLocalDb? _local;
  final CineFirebaseService? _remote;
  NetworkStatus? _network;
  final RemoteWriter? _writer;
  final FavoritesFetcher? _fetchFavorites;

  CineLocalDb get local => _local ?? CineLocalDb.instance;
  CineFirebaseService get remote => _remote ?? CineFirebaseService.instance;
  NetworkStatus get network => _network ??= ConnectivityNetworkStatus();

  bool _online = true;

  /// Dernier état connu (vrai tant que rien n'a été vérifié).
  bool get isOnline => _online;

  final _onlineChanges = StreamController<bool>.broadcast();
  final _events = StreamController<SyncEvent>.broadcast();

  /// Passage en ligne (true) ou hors ligne (false).
  Stream<bool> get onlineChanges => _onlineChanges.stream;

  /// Mises en file et fins de synchronisation.
  Stream<SyncEvent> get events => _events.stream;

  StreamSubscription<bool>? _subscription;
  Future<void>? _starting;

  /// Démarre l'écoute du réseau (sans effet si déjà démarrée) et
  /// synchronise tout de suite si des opérations attendent.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    _subscription = network.changes.listen(_setOnline);
    await _setOnline(await network.isOnline());
    if (_online) {
      unawaited(syncNow());
    }
  }

  Future<void> _setOnline(bool online) async {
    if (online == _online) {
      return;
    }
    _online = online;
    _onlineChanges.add(online);
    if (online) {
      await syncNow();
    }
  }

  /// Vérifie la connexion maintenant (bouton « Réessayer »).
  Future<bool> checkConnection() async {
    await _setOnline(await network.isOnline());
    return _online;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _starting = null;
  }

  Future<void> _send(PendingSyncOperation operation) async {
    try {
      await (_writer ?? _firestoreWrite)(operation).timeout(kSyncTimeout);
    } catch (error) {
      throw mapFirestoreError(error);
    }
  }

  Future<void> _firestoreWrite(PendingSyncOperation operation) async {
    final doc = remote.db.doc(operation.path);
    final fields = toFirestoreFields(operation.payload);
    switch (operation.operation) {
      case SyncOperation.set:
        await doc.set(fields);
      case SyncOperation.update:
        await doc.update(fields);
      case SyncOperation.delete:
        await doc.delete();
    }
  }

  /// Écrit dans Firestore si possible, sinon met l'opération en file.
  /// Renvoie true si l'écriture est partie, false si elle attend le réseau.
  /// Une erreur autre que réseau (droits, données invalides) est levée.
  Future<bool> write(PendingSyncOperation operation) async {
    if (!local.isSupported) {
      // Web : pas de SQLite, la persistance de Firestore garde l'écriture.
      unawaited((_writer ?? _firestoreWrite)(operation).catchError((Object e) =>
          developer.log('write', name: 'CineSyncService', error: e)));
      return true;
    }
    if (_online) {
      try {
        await _send(operation);
        return true;
      } on CineFailure catch (failure) {
        if (failure.kind != CineFailureKind.network) {
          rethrow;
        }
        await _setOnline(false);
      }
    }
    await local.enqueuePending(operation);
    _events.add(SyncEvent(SyncEventKind.queued,
        remaining: await local.pendingCount(userId: operation.userId)));
    return false;
  }

  Future<SyncEvent>? _running;

  /// Rejoue la file du membre connecté (un seul passage à la fois), puis
  /// recopie ses favoris dans SQLite.
  Future<SyncEvent> syncNow() =>
      _running ??= _replay().whenComplete(() => _running = null);

  Future<SyncEvent> _replay() async {
    final userId = remote.currentUserId;
    if (userId == null || !local.isSupported) {
      return const SyncEvent(SyncEventKind.synced);
    }
    var synced = 0, failed = 0, dropped = 0;
    var interrupted = false;
    for (final operation in await local.pendingOperations(userId: userId)) {
      try {
        await _send(operation);
        await local.removePending(operation.id!);
        synced++;
      } on CineFailure catch (failure) {
        if (failure.kind == CineFailureKind.network) {
          // Pas compté comme un échec : on reprendra au retour du réseau.
          interrupted = true;
          break;
        }
        if (operation.retryCount + 1 >= kMaxSyncRetries) {
          developer.log('abandon ${operation.path} : ${failure.message}',
              name: 'CineSyncService');
          await local.removePending(operation.id!);
          dropped++;
        } else {
          await local.markPendingFailed(operation.id!, failure.message);
          failed++;
        }
      }
    }
    if (interrupted) {
      await _setOnline(false);
    } else {
      await _pullFavorites(userId);
    }
    final event = SyncEvent(
      SyncEventKind.synced,
      synced: synced,
      failed: failed,
      dropped: dropped,
      remaining: await local.pendingCount(userId: userId),
      interrupted: interrupted,
    );
    _events.add(event);
    return event;
  }

  /// Favoris Firestore -> `local_favorites` (calendrier « mes favoris » et
  /// écran hors connexion).
  Future<void> _pullFavorites(String userId) async {
    try {
      final rows = await (_fetchFavorites ??
          () async => (await remote.mine('favorites').get())
              .docs
              .map(cineRow)
              .toList())();
      await local.replaceLocalFavorites(userId, rows);
    } catch (error) {
      developer.log('pullFavorites', name: 'CineSyncService', error: error);
    }
  }
}
