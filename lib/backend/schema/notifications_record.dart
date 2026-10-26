import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class NotificationsRecord extends FirestoreRecord {
  NotificationsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "userId" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  bool hasMessage() => _message != null;

  // "releaseEventId" field.
  String? _releaseEventId;
  String get releaseEventId => _releaseEventId ?? '';
  bool hasReleaseEventId() => _releaseEventId != null;

  // "scheduledAt" field.
  DateTime? _scheduledAt;
  DateTime? get scheduledAt => _scheduledAt;
  bool hasScheduledAt() => _scheduledAt != null;

  // "isRead" field.
  bool? _isRead;
  bool get isRead => _isRead ?? false;
  bool hasIsRead() => _isRead != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as String?;
    _title = snapshotData['title'] as String?;
    _message = snapshotData['message'] as String?;
    _releaseEventId = snapshotData['releaseEventId'] as String?;
    _scheduledAt = snapshotData['scheduledAt'] as DateTime?;
    _isRead = snapshotData['isRead'] as bool?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('notifications');

  static Stream<NotificationsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => NotificationsRecord.fromSnapshot(s));

  static Future<NotificationsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => NotificationsRecord.fromSnapshot(s));

  static NotificationsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      NotificationsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static NotificationsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      NotificationsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'NotificationsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is NotificationsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createNotificationsRecordData({
  String? userId,
  String? title,
  String? message,
  String? releaseEventId,
  DateTime? scheduledAt,
  bool? isRead,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'title': title,
      'message': message,
      'releaseEventId': releaseEventId,
      'scheduledAt': scheduledAt,
      'isRead': isRead,
      'createdAt': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class NotificationsRecordDocumentEquality
    implements Equality<NotificationsRecord> {
  const NotificationsRecordDocumentEquality();

  @override
  bool equals(NotificationsRecord? e1, NotificationsRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.title == e2?.title &&
        e1?.message == e2?.message &&
        e1?.releaseEventId == e2?.releaseEventId &&
        e1?.scheduledAt == e2?.scheduledAt &&
        e1?.isRead == e2?.isRead &&
        e1?.createdAt == e2?.createdAt;
  }

  @override
  int hash(NotificationsRecord? e) => const ListEquality().hash([
        e?.userId,
        e?.title,
        e?.message,
        e?.releaseEventId,
        e?.scheduledAt,
        e?.isRead,
        e?.createdAt
      ]);

  @override
  bool isValidKey(Object? o) => o is NotificationsRecord;
}
