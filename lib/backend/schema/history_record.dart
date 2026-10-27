import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class HistoryRecord extends FirestoreRecord {
  HistoryRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "mediaType" field.
  String? _mediaType;
  String get mediaType => _mediaType ?? '';
  bool hasMediaType() => _mediaType != null;

  // "tmdbId" field.
  int? _tmdbId;
  int get tmdbId => _tmdbId ?? 0;
  bool hasTmdbId() => _tmdbId != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "posterUrl" field.
  String? _posterUrl;
  String get posterUrl => _posterUrl ?? '';
  bool hasPosterUrl() => _posterUrl != null;

  // "viewedAt" field.
  DateTime? _viewedAt;
  DateTime? get viewedAt => _viewedAt;
  bool hasViewedAt() => _viewedAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _mediaType = snapshotData['mediaType'] as String?;
    _tmdbId = castToType<int>(snapshotData['tmdbId']);
    _title = snapshotData['title'] as String?;
    _posterUrl = snapshotData['posterUrl'] as String?;
    _viewedAt = snapshotData['viewedAt'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('history')
          : FirebaseFirestore.instance.collectionGroup('history');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('history').doc(id);

  static Stream<HistoryRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => HistoryRecord.fromSnapshot(s));

  static Future<HistoryRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => HistoryRecord.fromSnapshot(s));

  static HistoryRecord fromSnapshot(DocumentSnapshot snapshot) =>
      HistoryRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static HistoryRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      HistoryRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'HistoryRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is HistoryRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createHistoryRecordData({
  String? mediaType,
  int? tmdbId,
  String? title,
  String? posterUrl,
  DateTime? viewedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'mediaType': mediaType,
      'tmdbId': tmdbId,
      'title': title,
      'posterUrl': posterUrl,
      'viewedAt': viewedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class HistoryRecordDocumentEquality implements Equality<HistoryRecord> {
  const HistoryRecordDocumentEquality();

  @override
  bool equals(HistoryRecord? e1, HistoryRecord? e2) {
    return e1?.mediaType == e2?.mediaType &&
        e1?.tmdbId == e2?.tmdbId &&
        e1?.title == e2?.title &&
        e1?.posterUrl == e2?.posterUrl &&
        e1?.viewedAt == e2?.viewedAt;
  }

  @override
  int hash(HistoryRecord? e) => const ListEquality()
      .hash([e?.mediaType, e?.tmdbId, e?.title, e?.posterUrl, e?.viewedAt]);

  @override
  bool isValidKey(Object? o) => o is HistoryRecord;
}
