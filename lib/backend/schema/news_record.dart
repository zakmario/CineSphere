import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class NewsRecord extends FirestoreRecord {
  NewsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "mediaId" field.
  String? _mediaId;
  String get mediaId => _mediaId ?? '';
  bool hasMediaId() => _mediaId != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "summary" field.
  String? _summary;
  String get summary => _summary ?? '';
  bool hasSummary() => _summary != null;

  // "imageUrl" field.
  String? _imageUrl;
  String get imageUrl => _imageUrl ?? '';
  bool hasImageUrl() => _imageUrl != null;

  // "publishedAt" field.
  DateTime? _publishedAt;
  DateTime? get publishedAt => _publishedAt;
  bool hasPublishedAt() => _publishedAt != null;

  void _initializeFields() {
    _mediaId = snapshotData['mediaId'] as String?;
    _title = snapshotData['title'] as String?;
    _summary = snapshotData['summary'] as String?;
    _imageUrl = snapshotData['imageUrl'] as String?;
    _publishedAt = snapshotData['publishedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('news');

  static Stream<NewsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => NewsRecord.fromSnapshot(s));

  static Future<NewsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => NewsRecord.fromSnapshot(s));

  static NewsRecord fromSnapshot(DocumentSnapshot snapshot) => NewsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static NewsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      NewsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'NewsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is NewsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createNewsRecordData({
  String? mediaId,
  String? title,
  String? summary,
  String? imageUrl,
  DateTime? publishedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'mediaId': mediaId,
      'title': title,
      'summary': summary,
      'imageUrl': imageUrl,
      'publishedAt': publishedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class NewsRecordDocumentEquality implements Equality<NewsRecord> {
  const NewsRecordDocumentEquality();

  @override
  bool equals(NewsRecord? e1, NewsRecord? e2) {
    return e1?.mediaId == e2?.mediaId &&
        e1?.title == e2?.title &&
        e1?.summary == e2?.summary &&
        e1?.imageUrl == e2?.imageUrl &&
        e1?.publishedAt == e2?.publishedAt;
  }

  @override
  int hash(NewsRecord? e) => const ListEquality()
      .hash([e?.mediaId, e?.title, e?.summary, e?.imageUrl, e?.publishedAt]);

  @override
  bool isValidKey(Object? o) => o is NewsRecord;
}
