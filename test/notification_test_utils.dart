import 'dart:async';

import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';

typedef ScheduledNotification = ({
  String title,
  String body,
  DateTime at,
  NotificationChannelKind channel,
  String? payload,
});

/// Plugin de notifications simulé : note les notifications programmées
/// (par identifiant) et affichées.
class FakeNotifier implements LocalNotifier {
  bool ready = true;
  bool permission = true;
  String? launch;
  void Function(String? payload)? onTap;
  final scheduled = <int, ScheduledNotification>{};
  final shown = <String>[];
  var cancelAllCalls = 0;

  @override
  Future<bool> initialize(void Function(String? payload) onTap) async {
    this.onTap = onTap;
    return ready;
  }

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationChannelKind channel,
    String? payload,
  }) async =>
      scheduled[id] = (
        title: title,
        body: body,
        at: at,
        channel: channel,
        payload: payload,
      );

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationChannelKind channel,
    String? payload,
  }) async =>
      shown.add(title);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
  }
}

/// `users/{uid}/notifications` en mémoire.
class FakeNotificationStore extends NotificationStore {
  FakeNotificationStore({this.uid = 'u1'});

  String? uid;
  final docs = <String, NotificationEntry>{};
  final calls = <String>[];
  final _changes = StreamController<void>.broadcast();

  @override
  String? get userId => uid;

  void add(NotificationEntry entry) {
    docs[entry.id] = entry;
    _changes.add(null);
  }

  @override
  Future<NotificationPage> fetchPage(
      {Object? after, int pageSize = 20, required DateTime now}) async {
    calls.add('fetchPage ${after ?? 0}');
    final due = docs.values.where((n) => n.isDue(now)).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));
    final start = (after as int?) ?? 0;
    final items = due.skip(start).take(pageSize).toList();
    return NotificationPage(
      items: items,
      cursor: start + items.length,
      hasMore: start + items.length < due.length,
    );
  }

  List<NotificationEntry> get _unread =>
      docs.values.where((n) => !n.isRead).toList();

  @override
  Stream<List<NotificationEntry>> watchUnread() async* {
    yield _unread;
    await for (final _ in _changes.stream) {
      yield _unread;
    }
  }

  @override
  Future<void> save(NotificationEntry entry) async {
    calls.add('save ${entry.id}');
    add(entry);
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    docs.remove(id);
    _changes.add(null);
  }

  @override
  Future<void> markRead(String id) async {
    calls.add('markRead $id');
    final entry = docs[id];
    if (entry != null) {
      add(entry.copyWith(isRead: true));
    }
  }
}

NotificationEntry notificationEntry(
  String id, {
  required DateTime at,
  String mediaType = 'movie',
  int tmdbId = 550,
  bool isRead = false,
  String? title,
}) =>
    NotificationEntry(
      id: id,
      title: title ?? 'Titre $id',
      message: 'Sortie le 10 novembre 2026 à 20:00',
      mediaType: mediaType,
      tmdbId: tmdbId,
      releaseEventId: id,
      scheduledAt: at,
      isRead: isRead,
      createdAt: at,
    );
