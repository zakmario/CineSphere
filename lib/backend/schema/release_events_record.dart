import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReleaseEventsRecord extends FirestoreRecord {
  ReleaseEventsRecord._(
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

  // "releaseDate" field.
  DateTime? _releaseDate;
  DateTime? get releaseDate => _releaseDate;
  bool hasReleaseDate() => _releaseDate != null;

  // "platform" field.
  String? _platform;
  String get platform => _platform ?? '';
  bool hasPlatform() => _platform != null;

  // "seasonNumber" field.
  int? _seasonNumber;
  int get seasonNumber => _seasonNumber ?? 0;
  bool hasSeasonNumber() => _seasonNumber != null;

  // "episodeNumber" field.
  int? _episodeNumber;
  int get episodeNumber => _episodeNumber ?? 0;
  bool hasEpisodeNumber() => _episodeNumber != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  void _initializeFields() {
    _mediaType = snapshotData['mediaType'] as String?;
    _tmdbId = castToType<int>(snapshotData['tmdbId']);
    _title = snapshotData['title'] as String?;
    _posterUrl = snapshotData['posterUrl'] as String?;
    _releaseDate = snapshotData['releaseDate'] as DateTime?;
    _platform = snapshotData['platform'] as String?;
    _seasonNumber = castToType<int>(snapshotData['seasonNumber']);
    _episodeNumber = castToType<int>(snapshotData['episodeNumber']);
    _description = snapshotData['description'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('releaseEvents');

  static Stream<ReleaseEventsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ReleaseEventsRecord.fromSnapshot(s));

  static Future<ReleaseEventsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ReleaseEventsRecord.fromSnapshot(s));

  static ReleaseEventsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ReleaseEventsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ReleaseEventsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ReleaseEventsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ReleaseEventsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ReleaseEventsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createReleaseEventsRecordData({
  String? mediaType,
  int? tmdbId,
  String? title,
  String? posterUrl,
  DateTime? releaseDate,
  String? platform,
  int? seasonNumber,
  int? episodeNumber,
  String? description,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'mediaType': mediaType,
      'tmdbId': tmdbId,
      'title': title,
      'posterUrl': posterUrl,
      'releaseDate': releaseDate,
      'platform': platform,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'description': description,
    }.withoutNulls,
  );

  return firestoreData;
}

class ReleaseEventsRecordDocumentEquality
    implements Equality<ReleaseEventsRecord> {
  const ReleaseEventsRecordDocumentEquality();

  @override
  bool equals(ReleaseEventsRecord? e1, ReleaseEventsRecord? e2) {
    return e1?.mediaType == e2?.mediaType &&
        e1?.tmdbId == e2?.tmdbId &&
        e1?.title == e2?.title &&
        e1?.posterUrl == e2?.posterUrl &&
        e1?.releaseDate == e2?.releaseDate &&
        e1?.platform == e2?.platform &&
        e1?.seasonNumber == e2?.seasonNumber &&
        e1?.episodeNumber == e2?.episodeNumber &&
        e1?.description == e2?.description;
  }

  @override
  int hash(ReleaseEventsRecord? e) => const ListEquality().hash([
        e?.mediaType,
        e?.tmdbId,
        e?.title,
        e?.posterUrl,
        e?.releaseDate,
        e?.platform,
        e?.seasonNumber,
        e?.episodeNumber,
        e?.description
      ]);

  @override
  bool isValidKey(Object? o) => o is ReleaseEventsRecord;
}
