import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MoviesRecord extends FirestoreRecord {
  MoviesRecord._(
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

  // "releaseDate" field.
  DateTime? _releaseDate;
  DateTime? get releaseDate => _releaseDate;
  bool hasReleaseDate() => _releaseDate != null;

  // "duration" field.
  int? _duration;
  int get duration => _duration ?? 0;
  bool hasDuration() => _duration != null;

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
    _releaseDate = snapshotData['releaseDate'] as DateTime?;
    _duration = castToType<int>(snapshotData['duration']);
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
      FirebaseFirestore.instance.collection('movies');

  static Stream<MoviesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MoviesRecord.fromSnapshot(s));

  static Future<MoviesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MoviesRecord.fromSnapshot(s));

  static MoviesRecord fromSnapshot(DocumentSnapshot snapshot) => MoviesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MoviesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MoviesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MoviesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MoviesRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createMoviesRecordData({
  int? tmdbId,
  String? title,
  String? description,
  String? posterUrl,
  String? backdropUrl,
  DateTime? releaseDate,
  int? duration,
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
      'releaseDate': releaseDate,
      'duration': duration,
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

class MoviesRecordDocumentEquality implements Equality<MoviesRecord> {
  const MoviesRecordDocumentEquality();

  @override
  bool equals(MoviesRecord? e1, MoviesRecord? e2) {
    const listEquality = ListEquality();
    return e1?.tmdbId == e2?.tmdbId &&
        e1?.title == e2?.title &&
        e1?.description == e2?.description &&
        e1?.posterUrl == e2?.posterUrl &&
        e1?.backdropUrl == e2?.backdropUrl &&
        e1?.releaseDate == e2?.releaseDate &&
        e1?.duration == e2?.duration &&
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
  int hash(MoviesRecord? e) => const ListEquality().hash([
        e?.tmdbId,
        e?.title,
        e?.description,
        e?.posterUrl,
        e?.backdropUrl,
        e?.releaseDate,
        e?.duration,
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
  bool isValidKey(Object? o) => o is MoviesRecord;
}
