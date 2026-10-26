import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PlatformsRecord extends FirestoreRecord {
  PlatformsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  bool hasId() => _id != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "logoUrl" field.
  String? _logoUrl;
  String get logoUrl => _logoUrl ?? '';
  bool hasLogoUrl() => _logoUrl != null;

  void _initializeFields() {
    _id = castToType<int>(snapshotData['id']);
    _name = snapshotData['name'] as String?;
    _logoUrl = snapshotData['logoUrl'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('platforms');

  static Stream<PlatformsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => PlatformsRecord.fromSnapshot(s));

  static Future<PlatformsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => PlatformsRecord.fromSnapshot(s));

  static PlatformsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      PlatformsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static PlatformsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      PlatformsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'PlatformsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is PlatformsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createPlatformsRecordData({
  int? id,
  String? name,
  String? logoUrl,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
    }.withoutNulls,
  );

  return firestoreData;
}

class PlatformsRecordDocumentEquality implements Equality<PlatformsRecord> {
  const PlatformsRecordDocumentEquality();

  @override
  bool equals(PlatformsRecord? e1, PlatformsRecord? e2) {
    return e1?.id == e2?.id &&
        e1?.name == e2?.name &&
        e1?.logoUrl == e2?.logoUrl;
  }

  @override
  int hash(PlatformsRecord? e) =>
      const ListEquality().hash([e?.id, e?.name, e?.logoUrl]);

  @override
  bool isValidKey(Object? o) => o is PlatformsRecord;
}
