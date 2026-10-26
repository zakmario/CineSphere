import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WatchlistItemsRecord extends FirestoreRecord {
  WatchlistItemsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "id" field.
  String? _id;
  String get id => _id ?? '';
  bool hasId() => _id != null;

  // "watchlistId" field.
  String? _watchlistId;
  String get watchlistId => _watchlistId ?? '';
  bool hasWatchlistId() => _watchlistId != null;

  // "userId" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "mediaId" field.
  String? _mediaId;
  String get mediaId => _mediaId ?? '';
  bool hasMediaId() => _mediaId != null;

  // "addedAt" field.
  DateTime? _addedAt;
  DateTime? get addedAt => _addedAt;
  bool hasAddedAt() => _addedAt != null;

  void _initializeFields() {
    _id = snapshotData['id'] as String?;
    _watchlistId = snapshotData['watchlistId'] as String?;
    _userId = snapshotData['userId'] as String?;
    _mediaId = snapshotData['mediaId'] as String?;
    _addedAt = snapshotData['addedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('watchlist_items');

  static Stream<WatchlistItemsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WatchlistItemsRecord.fromSnapshot(s));

  static Future<WatchlistItemsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => WatchlistItemsRecord.fromSnapshot(s));

  static WatchlistItemsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WatchlistItemsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WatchlistItemsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WatchlistItemsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WatchlistItemsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WatchlistItemsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createWatchlistItemsRecordData({
  String? id,
  String? watchlistId,
  String? userId,
  String? mediaId,
  DateTime? addedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'id': id,
      'watchlistId': watchlistId,
      'userId': userId,
      'mediaId': mediaId,
      'addedAt': addedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class WatchlistItemsRecordDocumentEquality
    implements Equality<WatchlistItemsRecord> {
  const WatchlistItemsRecordDocumentEquality();

  @override
  bool equals(WatchlistItemsRecord? e1, WatchlistItemsRecord? e2) {
    return e1?.id == e2?.id &&
        e1?.watchlistId == e2?.watchlistId &&
        e1?.userId == e2?.userId &&
        e1?.mediaId == e2?.mediaId &&
        e1?.addedAt == e2?.addedAt;
  }

  @override
  int hash(WatchlistItemsRecord? e) => const ListEquality()
      .hash([e?.id, e?.watchlistId, e?.userId, e?.mediaId, e?.addedAt]);

  @override
  bool isValidKey(Object? o) => o is WatchlistItemsRecord;
}
