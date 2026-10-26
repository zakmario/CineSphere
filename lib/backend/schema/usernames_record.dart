import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UsernamesRecord extends FirestoreRecord {
  UsernamesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "userId" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "username" field.
  String? _username;
  String get username => _username ?? '';
  bool hasUsername() => _username != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as String?;
    _username = snapshotData['username'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('usernames');

  static Stream<UsernamesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UsernamesRecord.fromSnapshot(s));

  static Future<UsernamesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UsernamesRecord.fromSnapshot(s));

  static UsernamesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      UsernamesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UsernamesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UsernamesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UsernamesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsernamesRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createUsernamesRecordData({
  String? userId,
  String? username,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'username': username,
    }.withoutNulls,
  );

  return firestoreData;
}

class UsernamesRecordDocumentEquality implements Equality<UsernamesRecord> {
  const UsernamesRecordDocumentEquality();

  @override
  bool equals(UsernamesRecord? e1, UsernamesRecord? e2) {
    return e1?.userId == e2?.userId && e1?.username == e2?.username;
  }

  @override
  int hash(UsernamesRecord? e) =>
      const ListEquality().hash([e?.userId, e?.username]);

  @override
  bool isValidKey(Object? o) => o is UsernamesRecord;
}
