import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReviewsRecord extends FirestoreRecord {
  ReviewsRecord._(
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

  // "userAvatarUrl" field.
  String? _userAvatarUrl;
  String get userAvatarUrl => _userAvatarUrl ?? '';
  bool hasUserAvatarUrl() => _userAvatarUrl != null;

  // "mediaType" field.
  String? _mediaType;
  String get mediaType => _mediaType ?? '';
  bool hasMediaType() => _mediaType != null;

  // "tmdbId" field.
  int? _tmdbId;
  int get tmdbId => _tmdbId ?? 0;
  bool hasTmdbId() => _tmdbId != null;

  // "rating" field.
  int? _rating;
  int get rating => _rating ?? 0;
  bool hasRating() => _rating != null;

  // "content" field.
  String? _content;
  String get content => _content ?? '';
  bool hasContent() => _content != null;

  // "isPrivate" field.
  bool? _isPrivate;
  bool get isPrivate => _isPrivate ?? false;
  bool hasIsPrivate() => _isPrivate != null;

  // "likesCount" field.
  int? _likesCount;
  int get likesCount => _likesCount ?? 0;
  bool hasLikesCount() => _likesCount != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as String?;
    _username = snapshotData['username'] as String?;
    _userAvatarUrl = snapshotData['userAvatarUrl'] as String?;
    _mediaType = snapshotData['mediaType'] as String?;
    _tmdbId = castToType<int>(snapshotData['tmdbId']);
    _rating = castToType<int>(snapshotData['rating']);
    _content = snapshotData['content'] as String?;
    _isPrivate = snapshotData['isPrivate'] as bool?;
    _likesCount = castToType<int>(snapshotData['likesCount']);
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('reviews');

  static Stream<ReviewsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ReviewsRecord.fromSnapshot(s));

  static Future<ReviewsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ReviewsRecord.fromSnapshot(s));

  static ReviewsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ReviewsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ReviewsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ReviewsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ReviewsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ReviewsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createReviewsRecordData({
  String? userId,
  String? username,
  String? userAvatarUrl,
  String? mediaType,
  int? tmdbId,
  int? rating,
  String? content,
  bool? isPrivate,
  int? likesCount,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'mediaType': mediaType,
      'tmdbId': tmdbId,
      'rating': rating,
      'content': content,
      'isPrivate': isPrivate,
      'likesCount': likesCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class ReviewsRecordDocumentEquality implements Equality<ReviewsRecord> {
  const ReviewsRecordDocumentEquality();

  @override
  bool equals(ReviewsRecord? e1, ReviewsRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.username == e2?.username &&
        e1?.userAvatarUrl == e2?.userAvatarUrl &&
        e1?.mediaType == e2?.mediaType &&
        e1?.tmdbId == e2?.tmdbId &&
        e1?.rating == e2?.rating &&
        e1?.content == e2?.content &&
        e1?.isPrivate == e2?.isPrivate &&
        e1?.likesCount == e2?.likesCount &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(ReviewsRecord? e) => const ListEquality().hash([
        e?.userId,
        e?.username,
        e?.userAvatarUrl,
        e?.mediaType,
        e?.tmdbId,
        e?.rating,
        e?.content,
        e?.isPrivate,
        e?.likesCount,
        e?.createdAt,
        e?.updatedAt
      ]);

  @override
  bool isValidKey(Object? o) => o is ReviewsRecord;
}
