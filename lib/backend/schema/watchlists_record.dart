import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WatchlistsRecord extends FirestoreRecord {
  WatchlistsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "id" field.
  String? _id;
  String get id => _id ?? '';
  bool hasId() => _id != null;

  // "userId" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "isPublic" field.
  bool? _isPublic;
  bool get isPublic => _isPublic ?? false;
  bool hasIsPublic() => _isPublic != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  void _initializeFields() {
    _id = snapshotData['id'] as String?;
    _userId = snapshotData['userId'] as String?;
    _name = snapshotData['name'] as String?;
    _description = snapshotData['description'] as String?;
    _isPublic = snapshotData['isPublic'] as bool?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('watchlists');

  static Stream<WatchlistsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WatchlistsRecord.fromSnapshot(s));

  static Future<WatchlistsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => WatchlistsRecord.fromSnapshot(s));

  static WatchlistsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WatchlistsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WatchlistsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WatchlistsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WatchlistsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WatchlistsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createWatchlistsRecordData({
  String? id,
  String? userId,
  String? name,
  String? description,
  bool? isPublic,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'isPublic': isPublic,
      'createdAt': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class WatchlistsRecordDocumentEquality implements Equality<WatchlistsRecord> {
  const WatchlistsRecordDocumentEquality();

  @override
  bool equals(WatchlistsRecord? e1, WatchlistsRecord? e2) {
    return e1?.id == e2?.id &&
        e1?.userId == e2?.userId &&
        e1?.name == e2?.name &&
        e1?.description == e2?.description &&
        e1?.isPublic == e2?.isPublic &&
        e1?.createdAt == e2?.createdAt;
  }

  @override
  int hash(WatchlistsRecord? e) => const ListEquality().hash(
      [e?.id, e?.userId, e?.name, e?.description, e?.isPublic, e?.createdAt]);

  @override
  bool isValidKey(Object? o) => o is WatchlistsRecord;
}
