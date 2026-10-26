import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MediaRecord extends FirestoreRecord {
  MediaRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "id" field.
  String? _id;
  String get id => _id ?? '';
  bool hasId() => _id != null;

  // "mediaType" field.
  String? _mediaType;
  String get mediaType => _mediaType ?? '';
  bool hasMediaType() => _mediaType != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "titleLower" field.
  String? _titleLower;
  String get titleLower => _titleLower ?? '';
  bool hasTitleLower() => _titleLower != null;

  // "overview" field.
  String? _overview;
  String get overview => _overview ?? '';
  bool hasOverview() => _overview != null;

  // "posterUrl" field.
  String? _posterUrl;
  String get posterUrl => _posterUrl ?? '';
  bool hasPosterUrl() => _posterUrl != null;

  // "backdropUrl" field.
  String? _backdropUrl;
  String get backdropUrl => _backdropUrl ?? '';
  bool hasBackdropUrl() => _backdropUrl != null;

  // "releaseDate" field.
  DateTime? _releaseDate;
  DateTime? get releaseDate => _releaseDate;
  bool hasReleaseDate() => _releaseDate != null;

  // "runtimeMinutes" field.
  int? _runtimeMinutes;
  int get runtimeMinutes => _runtimeMinutes ?? 0;
  bool hasRuntimeMinutes() => _runtimeMinutes != null;

  // "seasons" field.
  int? _seasons;
  int get seasons => _seasons ?? 0;
  bool hasSeasons() => _seasons != null;

  // "episodes" field.
  int? _episodes;
  int get episodes => _episodes ?? 0;
  bool hasEpisodes() => _episodes != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "rating" field.
  double? _rating;
  double get rating => _rating ?? 0.0;
  bool hasRating() => _rating != null;

  // "popularity" field.
  int? _popularity;
  int get popularity => _popularity ?? 0;
  bool hasPopularity() => _popularity != null;

  // "genres" field.
  List<String>? _genres;
  List<String> get genres => _genres ?? const [];
  bool hasGenres() => _genres != null;

  // "platforms" field.
  List<String>? _platforms;
  List<String> get platforms => _platforms ?? const [];
  bool hasPlatforms() => _platforms != null;

  // "trailerUrl" field.
  String? _trailerUrl;
  String get trailerUrl => _trailerUrl ?? '';
  bool hasTrailerUrl() => _trailerUrl != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "tmdbId" field.
  int? _tmdbId;
  int get tmdbId => _tmdbId ?? 0;
  bool hasTmdbId() => _tmdbId != null;

  // "detailsSyncedAt" field.
  DateTime? _detailsSyncedAt;
  DateTime? get detailsSyncedAt => _detailsSyncedAt;
  bool hasDetailsSyncedAt() => _detailsSyncedAt != null;

  void _initializeFields() {
    _id = snapshotData['id'] as String?;
    _mediaType = snapshotData['mediaType'] as String?;
    _title = snapshotData['title'] as String?;
    _titleLower = snapshotData['titleLower'] as String?;
    _overview = snapshotData['overview'] as String?;
    _posterUrl = snapshotData['posterUrl'] as String?;
    _backdropUrl = snapshotData['backdropUrl'] as String?;
    _releaseDate = snapshotData['releaseDate'] as DateTime?;
    _runtimeMinutes = castToType<int>(snapshotData['runtimeMinutes']);
    _seasons = castToType<int>(snapshotData['seasons']);
    _episodes = castToType<int>(snapshotData['episodes']);
    _status = snapshotData['status'] as String?;
    _rating = castToType<double>(snapshotData['rating']);
    _popularity = castToType<int>(snapshotData['popularity']);
    _genres = getDataList(snapshotData['genres']);
    _platforms = getDataList(snapshotData['platforms']);
    _trailerUrl = snapshotData['trailerUrl'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _tmdbId = castToType<int>(snapshotData['tmdbId']);
    _detailsSyncedAt = snapshotData['detailsSyncedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('media');

  static Stream<MediaRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MediaRecord.fromSnapshot(s));

  static Future<MediaRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MediaRecord.fromSnapshot(s));

  static MediaRecord fromSnapshot(DocumentSnapshot snapshot) => MediaRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MediaRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MediaRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MediaRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MediaRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createMediaRecordData({
  String? id,
  String? mediaType,
  String? title,
  String? titleLower,
  String? overview,
  String? posterUrl,
  String? backdropUrl,
  DateTime? releaseDate,
  int? runtimeMinutes,
  int? seasons,
  int? episodes,
  String? status,
  double? rating,
  int? popularity,
  String? trailerUrl,
  DateTime? createdAt,
  int? tmdbId,
  DateTime? detailsSyncedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'id': id,
      'mediaType': mediaType,
      'title': title,
      'titleLower': titleLower,
      'overview': overview,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'releaseDate': releaseDate,
      'runtimeMinutes': runtimeMinutes,
      'seasons': seasons,
      'episodes': episodes,
      'status': status,
      'rating': rating,
      'popularity': popularity,
      'trailerUrl': trailerUrl,
      'createdAt': createdAt,
      'tmdbId': tmdbId,
      'detailsSyncedAt': detailsSyncedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class MediaRecordDocumentEquality implements Equality<MediaRecord> {
  const MediaRecordDocumentEquality();

  @override
  bool equals(MediaRecord? e1, MediaRecord? e2) {
    const listEquality = ListEquality();
    return e1?.id == e2?.id &&
        e1?.mediaType == e2?.mediaType &&
        e1?.title == e2?.title &&
        e1?.titleLower == e2?.titleLower &&
        e1?.overview == e2?.overview &&
        e1?.posterUrl == e2?.posterUrl &&
        e1?.backdropUrl == e2?.backdropUrl &&
        e1?.releaseDate == e2?.releaseDate &&
        e1?.runtimeMinutes == e2?.runtimeMinutes &&
        e1?.seasons == e2?.seasons &&
        e1?.episodes == e2?.episodes &&
        e1?.status == e2?.status &&
        e1?.rating == e2?.rating &&
        e1?.popularity == e2?.popularity &&
        listEquality.equals(e1?.genres, e2?.genres) &&
        listEquality.equals(e1?.platforms, e2?.platforms) &&
        e1?.trailerUrl == e2?.trailerUrl &&
        e1?.createdAt == e2?.createdAt &&
        e1?.tmdbId == e2?.tmdbId &&
        e1?.detailsSyncedAt == e2?.detailsSyncedAt;
  }

  @override
  int hash(MediaRecord? e) => const ListEquality().hash([
        e?.id,
        e?.mediaType,
        e?.title,
        e?.titleLower,
        e?.overview,
        e?.posterUrl,
        e?.backdropUrl,
        e?.releaseDate,
        e?.runtimeMinutes,
        e?.seasons,
        e?.episodes,
        e?.status,
        e?.rating,
        e?.popularity,
        const ListEquality().hash(e?.genres),
        const ListEquality().hash(e?.platforms),
        e?.trailerUrl,
        e?.createdAt,
        e?.tmdbId,
        e?.detailsSyncedAt
      ]);

  @override
  bool isValidKey(Object? o) => o is MediaRecord;
}
