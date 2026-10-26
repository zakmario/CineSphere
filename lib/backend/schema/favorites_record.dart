import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class FavoritesRecord extends FirestoreRecord {
  FavoritesRecord._(
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

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as String?;
    _mediaId = snapshotData['mediaId'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('favorites');

  static Stream<FavoritesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => FavoritesRecord.fromSnapshot(s));

  static Future<FavoritesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => FavoritesRecord.fromSnapshot(s));

  static FavoritesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      FavoritesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static FavoritesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      FavoritesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'FavoritesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is FavoritesRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createFavoritesRecordData({
  String? userId,
  String? mediaId,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'mediaId': mediaId,
      'createdAt': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class FavoritesRecordDocumentEquality implements Equality<FavoritesRecord> {
  const FavoritesRecordDocumentEquality();

  @override
  bool equals(FavoritesRecord? e1, FavoritesRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.mediaId == e2?.mediaId &&
        e1?.createdAt == e2?.createdAt;
  }

  @override
  int hash(FavoritesRecord? e) =>
      const ListEquality().hash([e?.userId, e?.mediaId, e?.createdAt]);

  @override
  bool isValidKey(Object? o) => o is FavoritesRecord;
}
