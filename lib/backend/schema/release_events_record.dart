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

  // "mediaId" field.
  String? _mediaId;
  String get mediaId => _mediaId ?? '';
  bool hasMediaId() => _mediaId != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "releaseAt" field.
  DateTime? _releaseAt;
  DateTime? get releaseAt => _releaseAt;
  bool hasReleaseAt() => _releaseAt != null;

  // "platform" field.
  String? _platform;
  String get platform => _platform ?? '';
  bool hasPlatform() => _platform != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "seasonNumber" field.
  int? _seasonNumber;
  int get seasonNumber => _seasonNumber ?? 0;
  bool hasSeasonNumber() => _seasonNumber != null;

  // "episodeNumber" field.
  int? _episodeNumber;
  int get episodeNumber => _episodeNumber ?? 0;
  bool hasEpisodeNumber() => _episodeNumber != null;

  // "releaseDate" field.
  DateTime? _releaseDate;
  DateTime? get releaseDate => _releaseDate;
  bool hasReleaseDate() => _releaseDate != null;

  void _initializeFields() {
    _mediaId = snapshotData['mediaId'] as String?;
    _title = snapshotData['title'] as String?;
    _releaseAt = snapshotData['releaseAt'] as DateTime?;
    _platform = snapshotData['platform'] as String?;
    _description = snapshotData['description'] as String?;
    _seasonNumber = castToType<int>(snapshotData['seasonNumber']);
    _episodeNumber = castToType<int>(snapshotData['episodeNumber']);
    _releaseDate = snapshotData['releaseDate'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('release_events');

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
  String? mediaId,
  String? title,
  DateTime? releaseAt,
  String? platform,
  String? description,
  int? seasonNumber,
  int? episodeNumber,
  DateTime? releaseDate,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'mediaId': mediaId,
      'title': title,
      'releaseAt': releaseAt,
      'platform': platform,
      'description': description,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'releaseDate': releaseDate,
    }.withoutNulls,
  );

  return firestoreData;
}

class ReleaseEventsRecordDocumentEquality
    implements Equality<ReleaseEventsRecord> {
  const ReleaseEventsRecordDocumentEquality();

  @override
  bool equals(ReleaseEventsRecord? e1, ReleaseEventsRecord? e2) {
    return e1?.mediaId == e2?.mediaId &&
        e1?.title == e2?.title &&
        e1?.releaseAt == e2?.releaseAt &&
        e1?.platform == e2?.platform &&
        e1?.description == e2?.description &&
        e1?.seasonNumber == e2?.seasonNumber &&
        e1?.episodeNumber == e2?.episodeNumber &&
        e1?.releaseDate == e2?.releaseDate;
  }

  @override
  int hash(ReleaseEventsRecord? e) => const ListEquality().hash([
        e?.mediaId,
        e?.title,
        e?.releaseAt,
        e?.platform,
        e?.description,
        e?.seasonNumber,
        e?.episodeNumber,
        e?.releaseDate
      ]);

  @override
  bool isValidKey(Object? o) => o is ReleaseEventsRecord;
}
