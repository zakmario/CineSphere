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

  // "itemCount" field.
  int? _itemCount;
  int get itemCount => _itemCount ?? 0;
  bool hasItemCount() => _itemCount != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _description = snapshotData['description'] as String?;
    _isPublic = snapshotData['isPublic'] as bool?;
    _itemCount = castToType<int>(snapshotData['itemCount']);
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('watchlists')
          : FirebaseFirestore.instance.collectionGroup('watchlists');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('watchlists').doc(id);

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
  String? name,
  String? description,
  bool? isPublic,
  int? itemCount,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'description': description,
      'isPublic': isPublic,
      'itemCount': itemCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class WatchlistsRecordDocumentEquality implements Equality<WatchlistsRecord> {
  const WatchlistsRecordDocumentEquality();

  @override
  bool equals(WatchlistsRecord? e1, WatchlistsRecord? e2) {
    return e1?.name == e2?.name &&
        e1?.description == e2?.description &&
        e1?.isPublic == e2?.isPublic &&
        e1?.itemCount == e2?.itemCount &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(WatchlistsRecord? e) => const ListEquality().hash([
        e?.name,
        e?.description,
        e?.isPublic,
        e?.itemCount,
        e?.createdAt,
        e?.updatedAt
      ]);

  @override
  bool isValidKey(Object? o) => o is WatchlistsRecord;
}
