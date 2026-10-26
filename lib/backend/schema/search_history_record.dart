import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SearchHistoryRecord extends FirestoreRecord {
  SearchHistoryRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "userId" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "query" field.
  String? _query;
  String get query => _query ?? '';
  bool hasQuery() => _query != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as String?;
    _query = snapshotData['query'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('search_history');

  static Stream<SearchHistoryRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => SearchHistoryRecord.fromSnapshot(s));

  static Future<SearchHistoryRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => SearchHistoryRecord.fromSnapshot(s));

  static SearchHistoryRecord fromSnapshot(DocumentSnapshot snapshot) =>
      SearchHistoryRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static SearchHistoryRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      SearchHistoryRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'SearchHistoryRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is SearchHistoryRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createSearchHistoryRecordData({
  String? userId,
  String? query,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'query': query,
      'createdAt': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class SearchHistoryRecordDocumentEquality
    implements Equality<SearchHistoryRecord> {
  const SearchHistoryRecordDocumentEquality();

  @override
  bool equals(SearchHistoryRecord? e1, SearchHistoryRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.query == e2?.query &&
        e1?.createdAt == e2?.createdAt;
  }

  @override
  int hash(SearchHistoryRecord? e) =>
      const ListEquality().hash([e?.userId, e?.query, e?.createdAt]);

  @override
  bool isValidKey(Object? o) => o is SearchHistoryRecord;
}
