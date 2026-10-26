import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WatchedRecord extends FirestoreRecord {
  WatchedRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "userId" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "mediaId" field.
  String? _mediaId;
  String get mediaId => _mediaId ?? '';
  bool hasMediaId() => _mediaId != null;

  // "watchedAt" field.
  DateTime? _watchedAt;
  DateTime? get watchedAt => _watchedAt;
  bool hasWatchedAt() => _watchedAt != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as String?;
    _mediaId = snapshotData['mediaId'] as String?;
    _watchedAt = snapshotData['watchedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('watched');

  static Stream<WatchedRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WatchedRecord.fromSnapshot(s));

  static Future<WatchedRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => WatchedRecord.fromSnapshot(s));

  static WatchedRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WatchedRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WatchedRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WatchedRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WatchedRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WatchedRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createWatchedRecordData({
  String? userId,
  String? mediaId,
  DateTime? watchedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'mediaId': mediaId,
      'watchedAt': watchedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class WatchedRecordDocumentEquality implements Equality<WatchedRecord> {
  const WatchedRecordDocumentEquality();

  @override
  bool equals(WatchedRecord? e1, WatchedRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.mediaId == e2?.mediaId &&
        e1?.watchedAt == e2?.watchedAt;
  }

  @override
  int hash(WatchedRecord? e) =>
      const ListEquality().hash([e?.userId, e?.mediaId, e?.watchedAt]);

  @override
  bool isValidKey(Object? o) => o is WatchedRecord;
}
