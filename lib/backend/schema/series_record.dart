import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SeriesRecord extends FirestoreRecord {
  SeriesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "tmdbId" field.
  int? _tmdbId;
  int get tmdbId => _tmdbId ?? 0;
  bool hasTmdbId() => _tmdbId != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "posterUrl" field.
  String? _posterUrl;
  String get posterUrl => _posterUrl ?? '';
  bool hasPosterUrl() => _posterUrl != null;

  // "backdropUrl" field.
  String? _backdropUrl;
  String get backdropUrl => _backdropUrl ?? '';
  bool hasBackdropUrl() => _backdropUrl != null;

  // "firstAirDate" field.
  DateTime? _firstAirDate;
  DateTime? get firstAirDate => _firstAirDate;
  bool hasFirstAirDate() => _firstAirDate != null;

  // "numberOfSeasons" field.
  int? _numberOfSeasons;
  int get numberOfSeasons => _numberOfSeasons ?? 0;
  bool hasNumberOfSeasons() => _numberOfSeasons != null;

  // "numberOfEpisodes" field.
  int? _numberOfEpisodes;
  int get numberOfEpisodes => _numberOfEpisodes ?? 0;
  bool hasNumberOfEpisodes() => _numberOfEpisodes != null;

  // "rating" field.
  double? _rating;
  double get rating => _rating ?? 0.0;
  bool hasRating() => _rating != null;

  // "trailerUrl" field.
  String? _trailerUrl;
  String get trailerUrl => _trailerUrl ?? '';
  bool hasTrailerUrl() => _trailerUrl != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "genreIds" field.
  List<int>? _genreIds;
  List<int> get genreIds => _genreIds ?? const [];
  bool hasGenreIds() => _genreIds != null;

  // "platforms" field.
  List<String>? _platforms;
  List<String> get platforms => _platforms ?? const [];
  bool hasPlatforms() => _platforms != null;

  // "popularity" field.
  int? _popularity;
  int get popularity => _popularity ?? 0;
  bool hasPopularity() => _popularity != null;

  // "detailsSyncedAt" field.
  DateTime? _detailsSyncedAt;
  DateTime? get detailsSyncedAt => _detailsSyncedAt;
  bool hasDetailsSyncedAt() => _detailsSyncedAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  void _initializeFields() {
    _tmdbId = castToType<int>(snapshotData['tmdbId']);
    _title = snapshotData['title'] as String?;
    _description = snapshotData['description'] as String?;
    _posterUrl = snapshotData['posterUrl'] as String?;
    _backdropUrl = snapshotData['backdropUrl'] as String?;
    _firstAirDate = snapshotData['firstAirDate'] as DateTime?;
    _numberOfSeasons = castToType<int>(snapshotData['numberOfSeasons']);
    _numberOfEpisodes = castToType<int>(snapshotData['numberOfEpisodes']);
    _rating = castToType<double>(snapshotData['rating']);
    _trailerUrl = snapshotData['trailerUrl'] as String?;
    _status = snapshotData['status'] as String?;
    _genreIds = getDataList(snapshotData['genreIds']);
    _platforms = getDataList(snapshotData['platforms']);
    _popularity = castToType<int>(snapshotData['popularity']);
    _detailsSyncedAt = snapshotData['detailsSyncedAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('series');

  static Stream<SeriesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => SeriesRecord.fromSnapshot(s));

  static Future<SeriesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => SeriesRecord.fromSnapshot(s));

  static SeriesRecord fromSnapshot(DocumentSnapshot snapshot) => SeriesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static SeriesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      SeriesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'SeriesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is SeriesRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createSeriesRecordData({
  int? tmdbId,
  String? title,
  String? description,
  String? posterUrl,
  String? backdropUrl,
  DateTime? firstAirDate,
  int? numberOfSeasons,
  int? numberOfEpisodes,
  double? rating,
  String? trailerUrl,
  String? status,
  int? popularity,
  DateTime? detailsSyncedAt,
  DateTime? updatedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'tmdbId': tmdbId,
      'title': title,
      'description': description,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'firstAirDate': firstAirDate,
      'numberOfSeasons': numberOfSeasons,
      'numberOfEpisodes': numberOfEpisodes,
      'rating': rating,
      'trailerUrl': trailerUrl,
      'status': status,
      'popularity': popularity,
      'detailsSyncedAt': detailsSyncedAt,
      'updatedAt': updatedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class SeriesRecordDocumentEquality implements Equality<SeriesRecord> {
  const SeriesRecordDocumentEquality();

  @override
  bool equals(SeriesRecord? e1, SeriesRecord? e2) {
    const listEquality = ListEquality();
    return e1?.tmdbId == e2?.tmdbId &&
        e1?.title == e2?.title &&
        e1?.description == e2?.description &&
        e1?.posterUrl == e2?.posterUrl &&
        e1?.backdropUrl == e2?.backdropUrl &&
        e1?.firstAirDate == e2?.firstAirDate &&
        e1?.numberOfSeasons == e2?.numberOfSeasons &&
        e1?.numberOfEpisodes == e2?.numberOfEpisodes &&
        e1?.rating == e2?.rating &&
        e1?.trailerUrl == e2?.trailerUrl &&
        e1?.status == e2?.status &&
        listEquality.equals(e1?.genreIds, e2?.genreIds) &&
        listEquality.equals(e1?.platforms, e2?.platforms) &&
        e1?.popularity == e2?.popularity &&
        e1?.detailsSyncedAt == e2?.detailsSyncedAt &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(SeriesRecord? e) => const ListEquality().hash([
        e?.tmdbId,
        e?.title,
        e?.description,
        e?.posterUrl,
        e?.backdropUrl,
        e?.firstAirDate,
        e?.numberOfSeasons,
        e?.numberOfEpisodes,
        e?.rating,
        e?.trailerUrl,
        e?.status,
        const ListEquality().hash(e?.genreIds),
        const ListEquality().hash(e?.platforms),
        e?.popularity,
        e?.detailsSyncedAt,
        e?.updatedAt
      ]);

  @override
  bool isValidKey(Object? o) => o is SeriesRecord;
}
