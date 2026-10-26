import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WatchedRecord extends FirestoreRecord {
  WatchedRecord._(
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

  // "seasonNumber" field.
  int? _seasonNumber;
  int get seasonNumber => _seasonNumber ?? 0;
  bool hasSeasonNumber() => _seasonNumber != null;

  // "episodeNumber" field.
  int? _episodeNumber;
  int get episodeNumber => _episodeNumber ?? 0;
  bool hasEpisodeNumber() => _episodeNumber != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "posterUrl" field.
  String? _posterUrl;
  String get posterUrl => _posterUrl ?? '';
  bool hasPosterUrl() => _posterUrl != null;

  // "watchedAt" field.
  DateTime? _watchedAt;
  DateTime? get watchedAt => _watchedAt;
  bool hasWatchedAt() => _watchedAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _mediaType = snapshotData['mediaType'] as String?;
    _tmdbId = castToType<int>(snapshotData['tmdbId']);
    _seasonNumber = castToType<int>(snapshotData['seasonNumber']);
    _episodeNumber = castToType<int>(snapshotData['episodeNumber']);
    _title = snapshotData['title'] as String?;
    _posterUrl = snapshotData['posterUrl'] as String?;
    _watchedAt = snapshotData['watchedAt'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('watched')
          : FirebaseFirestore.instance.collectionGroup('watched');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('watched').doc(id);

  static Stream<WatchedRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WatchedRecord.fromSnapshot(s));

  static Future<WatchedRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => WatchedRecord.fromSnapshot(s));

  static WatchedRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WatchedRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WatchedRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WatchedRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WatchedRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WatchedRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createWatchedRecordData({
  String? mediaType,
  int? tmdbId,
  int? seasonNumber,
  int? episodeNumber,
  String? title,
  String? posterUrl,
  DateTime? watchedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'mediaType': mediaType,
      'tmdbId': tmdbId,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'title': title,
      'posterUrl': posterUrl,
      'watchedAt': watchedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class WatchedRecordDocumentEquality implements Equality<WatchedRecord> {
  const WatchedRecordDocumentEquality();

  @override
  bool equals(WatchedRecord? e1, WatchedRecord? e2) {
    return e1?.mediaType == e2?.mediaType &&
        e1?.tmdbId == e2?.tmdbId &&
        e1?.seasonNumber == e2?.seasonNumber &&
        e1?.episodeNumber == e2?.episodeNumber &&
        e1?.title == e2?.title &&
        e1?.posterUrl == e2?.posterUrl &&
        e1?.watchedAt == e2?.watchedAt;
  }

  @override
  int hash(WatchedRecord? e) => const ListEquality().hash([
        e?.mediaType,
        e?.tmdbId,
        e?.seasonNumber,
        e?.episodeNumber,
        e?.title,
        e?.posterUrl,
        e?.watchedAt
      ]);

  @override
  bool isValidKey(Object? o) => o is WatchedRecord;
}
