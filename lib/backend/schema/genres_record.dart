import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class GenresRecord extends FirestoreRecord {
  GenresRecord._(
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

  void _initializeFields() {
    _id = castToType<int>(snapshotData['id']);
    _name = snapshotData['name'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('genres');

  static Stream<GenresRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => GenresRecord.fromSnapshot(s));

  static Future<GenresRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => GenresRecord.fromSnapshot(s));

  static GenresRecord fromSnapshot(DocumentSnapshot snapshot) => GenresRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static GenresRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      GenresRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'GenresRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is GenresRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createGenresRecordData({
  int? id,
  String? name,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'id': id,
      'name': name,
    }.withoutNulls,
  );

  return firestoreData;
}

class GenresRecordDocumentEquality implements Equality<GenresRecord> {
  const GenresRecordDocumentEquality();

  @override
  bool equals(GenresRecord? e1, GenresRecord? e2) {
    return e1?.id == e2?.id && e1?.name == e2?.name;
  }

  @override
  int hash(GenresRecord? e) => const ListEquality().hash([e?.id, e?.name]);

  @override
  bool isValidKey(Object? o) => o is GenresRecord;
}
