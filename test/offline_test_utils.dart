import 'dart:async';

import 'package:cine_sphere/custom_code/actions/cine_local_db.dart';
import 'package:cine_sphere/custom_code/actions/cine_sync_service.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Réseau simulé : [online] au démarrage, [set] simule un changement.
class FakeNetwork implements NetworkStatus {
  FakeNetwork({this.online = true});

  bool online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool value) {
    online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get changes => _changes.stream;
}

/// Firestore simulé pour la synchronisation : note les opérations reçues ;
/// [errors] (par docId) fait échouer l'envoi avec un code Firestore.
class FakeRemoteWriter {
  final sent = <PendingSyncOperation>[];
  final errors = <String, String>{};
  List<Map<String, dynamic>> favorites = [];

  /// Si présent, chaque envoi attend sa fin (synchronisation « en cours »).
  Completer<void>? gate;

  Future<void> call(PendingSyncOperation operation) async {
    await gate?.future;
    final code = errors[operation.docId];
    if (code != null) {
      throw FirebaseException(plugin: 'cloud_firestore', code: code);
    }
    sent.add(operation);
  }

  Future<List<Map<String, dynamic>>> fetchFavorites() async => favorites;
}

/// Base locale en mémoire pour les tests de widgets : sqflite attend de
/// vrais délais, que `testWidgets` (temps simulé) ne laisse pas passer.
/// SQLite lui-même est testé dans cine_local_db_test.dart.
class MemoryLocalDb extends CineLocalDb {
  MemoryLocalDb({super.now}) : super(supported: true);

  /// Sorties en cache (calendar_events) et date de leur enregistrement.
  final calendar = <Map<String, dynamic>>[];
  DateTime? calendarCachedAt;

  /// Sorties renvoyées par « Firestore » ; [offline] : erreur réseau.
  List<Map<String, dynamic>> remoteEvents = [];
  bool offline = false;

  bool _inRange(Map<String, dynamic> e, DateTime from, DateTime to) {
    final date = releaseDateOf(e)!;
    return !date.isBefore(from) && date.isBefore(to);
  }

  @override
  Future<CachedValue<List<Map<String, dynamic>>>?> readCalendarRange(
      DateTime from, DateTime to) async {
    final rows = calendar.where((e) => _inRange(e, from, to)).toList();
    return rows.isEmpty ? null : CachedValue(rows, calendarCachedAt ?? now());
  }

  @override
  Future<void> replaceCalendarRange(
      DateTime from, DateTime to, List<Map<String, dynamic>> rows) async {
    calendar
      ..removeWhere((e) => _inRange(e, from, to))
      ..addAll(rows);
    calendarCachedAt = now();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReleaseEvents(
      DateTime from, DateTime to) async {
    if (offline) {
      throw const CineFailure(
          CineFailureKind.network, 'Pas de connexion Internet.');
    }
    return remoteEvents.where((e) => _inRange(e, from, to)).toList();
  }

  final catalog = <Map<String, dynamic>>[];
  final favorites = <String, List<Map<String, dynamic>>>{};
  final pending = <PendingSyncOperation>[];
  var _nextId = 0;

  @override
  Future<void> saveCatalog(List<Map<String, dynamic>> rows,
      {bool replaceAll = false}) async {
    if (replaceAll) {
      catalog.clear();
    }
    catalog.addAll(rows);
  }

  @override
  Future<CachedValue<List<Map<String, dynamic>>>?> readCatalog() async =>
      catalog.isEmpty
          ? null
          : CachedValue(
              [...catalog]..sort((a, b) => ((b['popularity'] as num?) ?? 0)
                  .compareTo((a['popularity'] as num?) ?? 0)),
              DateTime.utc(2026, 10, 27));

  @override
  Future<void> setLocalFavorite(
      String userId, Map<String, dynamic> row, bool favorite) async {
    final list = favorites.putIfAbsent(userId, () => []);
    list.removeWhere((f) => f['id'] == row['id']);
    if (favorite) {
      list.insert(0, row);
    }
  }

  @override
  Future<void> replaceLocalFavorites(
          String userId, List<Map<String, dynamic>> rows) async =>
      favorites[userId] = [...rows];

  @override
  Future<List<Map<String, dynamic>>> localFavorites(String userId) async =>
      favorites[userId] ?? const [];

  @override
  Future<int> enqueuePending(PendingSyncOperation operation) async {
    final id = ++_nextId;
    pending.add(PendingSyncOperation.fromMap(operation.toMap()..['id'] = id));
    return id;
  }

  @override
  Future<List<PendingSyncOperation>> pendingOperations(
          {String? userId}) async =>
      pending.where((o) => userId == null || o.userId == userId).toList();

  @override
  Future<int> pendingCount({String? userId}) async =>
      (await pendingOperations(userId: userId)).length;

  @override
  Future<void> removePending(int id) async =>
      pending.removeWhere((o) => o.id == id);

  @override
  Future<void> markPendingFailed(int id, Object error) async {}

  @override
  Future<void> clearPrivateData({String? userId}) async {
    if (userId == null) {
      favorites.clear();
    } else {
      favorites.remove(userId);
    }
    pending.removeWhere((o) => userId == null || o.userId == userId);
  }

  @override
  Future<void> clearPersonalCache() async {}
}

PendingSyncOperation favoriteOp(
  String docId, {
  SyncOperation operation = SyncOperation.set,
  String userId = 'u1',
  Map<String, dynamic> payload = const {},
}) =>
    PendingSyncOperation(
      userId: userId,
      operation: operation,
      collection: 'users/$userId/favorites',
      docId: docId,
      payload: payload,
      createdAt: DateTime.utc(2026, 10, 28),
    );
