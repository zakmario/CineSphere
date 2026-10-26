import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UsersRecord extends FirestoreRecord {
  UsersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "id" field.
  String? _id;
  String get id => _id ?? '';
  bool hasId() => _id != null;

  // "username" field.
  String? _username;
  String get username => _username ?? '';
  bool hasUsername() => _username != null;

  // "usernameLower" field.
  String? _usernameLower;
  String get usernameLower => _usernameLower ?? '';
  bool hasUsernameLower() => _usernameLower != null;

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "avatarUrl" field.
  String? _avatarUrl;
  String get avatarUrl => _avatarUrl ?? '';
  bool hasAvatarUrl() => _avatarUrl != null;

  // "avatarData" field.
  String? _avatarData;
  String get avatarData => _avatarData ?? '';
  bool hasAvatarData() => _avatarData != null;

  // "bio" field.
  String? _bio;
  String get bio => _bio ?? '';
  bool hasBio() => _bio != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  bool hasRole() => _role != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  // "favoriteGenres" field.
  List<int>? _favoriteGenres;
  List<int> get favoriteGenres => _favoriteGenres ?? const [];
  bool hasFavoriteGenres() => _favoriteGenres != null;

  // "favoritePlatforms" field.
  List<String>? _favoritePlatforms;
  List<String> get favoritePlatforms => _favoritePlatforms ?? const [];
  bool hasFavoritePlatforms() => _favoritePlatforms != null;

  // "contentTypes" field.
  List<String>? _contentTypes;
  List<String> get contentTypes => _contentTypes ?? const [];
  bool hasContentTypes() => _contentTypes != null;

  // "notificationsEnabled" field.
  bool? _notificationsEnabled;
  bool get notificationsEnabled => _notificationsEnabled ?? false;
  bool hasNotificationsEnabled() => _notificationsEnabled != null;

  // "notifyReleases" field.
  bool? _notifyReleases;
  bool get notifyReleases => _notifyReleases ?? false;
  bool hasNotifyReleases() => _notifyReleases != null;

  // "notifyFavoriteSeries" field.
  bool? _notifyFavoriteSeries;
  bool get notifyFavoriteSeries => _notifyFavoriteSeries ?? false;
  bool hasNotifyFavoriteSeries() => _notifyFavoriteSeries != null;

  // "reminderTime" field.
  String? _reminderTime;
  String get reminderTime => _reminderTime ?? '';
  bool hasReminderTime() => _reminderTime != null;

  // "themeMode" field.
  String? _themeMode;
  String get themeMode => _themeMode ?? '';
  bool hasThemeMode() => _themeMode != null;

  // "onboardingCompleted" field.
  bool? _onboardingCompleted;
  bool get onboardingCompleted => _onboardingCompleted ?? false;
  bool hasOnboardingCompleted() => _onboardingCompleted != null;

  void _initializeFields() {
    _id = snapshotData['id'] as String?;
    _username = snapshotData['username'] as String?;
    _usernameLower = snapshotData['usernameLower'] as String?;
    _email = snapshotData['email'] as String?;
    _avatarUrl = snapshotData['avatarUrl'] as String?;
    _avatarData = snapshotData['avatarData'] as String?;
    _bio = snapshotData['bio'] as String?;
    _role = snapshotData['role'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
    _favoriteGenres = getDataList(snapshotData['favoriteGenres']);
    _favoritePlatforms = getDataList(snapshotData['favoritePlatforms']);
    _contentTypes = getDataList(snapshotData['contentTypes']);
    _notificationsEnabled = snapshotData['notificationsEnabled'] as bool?;
    _notifyReleases = snapshotData['notifyReleases'] as bool?;
    _notifyFavoriteSeries = snapshotData['notifyFavoriteSeries'] as bool?;
    _reminderTime = snapshotData['reminderTime'] as String?;
    _themeMode = snapshotData['themeMode'] as String?;
    _onboardingCompleted = snapshotData['onboardingCompleted'] as bool?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('users');

  static Stream<UsersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UsersRecord.fromSnapshot(s));

  static Future<UsersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UsersRecord.fromSnapshot(s));

  static UsersRecord fromSnapshot(DocumentSnapshot snapshot) => UsersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UsersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UsersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UsersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsersRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createUsersRecordData({
  String? id,
  String? username,
  String? usernameLower,
  String? email,
  String? avatarUrl,
  String? avatarData,
  String? bio,
  String? role,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool? notificationsEnabled,
  bool? notifyReleases,
  bool? notifyFavoriteSeries,
  String? reminderTime,
  String? themeMode,
  bool? onboardingCompleted,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'id': id,
      'username': username,
      'usernameLower': usernameLower,
      'email': email,
      'avatarUrl': avatarUrl,
      'avatarData': avatarData,
      'bio': bio,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'notificationsEnabled': notificationsEnabled,
      'notifyReleases': notifyReleases,
      'notifyFavoriteSeries': notifyFavoriteSeries,
      'reminderTime': reminderTime,
      'themeMode': themeMode,
      'onboardingCompleted': onboardingCompleted,
    }.withoutNulls,
  );

  return firestoreData;
}

class UsersRecordDocumentEquality implements Equality<UsersRecord> {
  const UsersRecordDocumentEquality();

  @override
  bool equals(UsersRecord? e1, UsersRecord? e2) {
    const listEquality = ListEquality();
    return e1?.id == e2?.id &&
        e1?.username == e2?.username &&
        e1?.usernameLower == e2?.usernameLower &&
        e1?.email == e2?.email &&
        e1?.avatarUrl == e2?.avatarUrl &&
        e1?.avatarData == e2?.avatarData &&
        e1?.bio == e2?.bio &&
        e1?.role == e2?.role &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt &&
        listEquality.equals(e1?.favoriteGenres, e2?.favoriteGenres) &&
        listEquality.equals(e1?.favoritePlatforms, e2?.favoritePlatforms) &&
        listEquality.equals(e1?.contentTypes, e2?.contentTypes) &&
        e1?.notificationsEnabled == e2?.notificationsEnabled &&
        e1?.notifyReleases == e2?.notifyReleases &&
        e1?.notifyFavoriteSeries == e2?.notifyFavoriteSeries &&
        e1?.reminderTime == e2?.reminderTime &&
        e1?.themeMode == e2?.themeMode &&
        e1?.onboardingCompleted == e2?.onboardingCompleted;
  }

  @override
  int hash(UsersRecord? e) => const ListEquality().hash([
        e?.id,
        e?.username,
        e?.usernameLower,
        e?.email,
        e?.avatarUrl,
        e?.avatarData,
        e?.bio,
        e?.role,
        e?.createdAt,
        e?.updatedAt,
        const ListEquality().hash(e?.favoriteGenres),
        const ListEquality().hash(e?.favoritePlatforms),
        const ListEquality().hash(e?.contentTypes),
        e?.notificationsEnabled,
        e?.notifyReleases,
        e?.notifyFavoriteSeries,
        e?.reminderTime,
        e?.themeMode,
        e?.onboardingCompleted
      ]);

  @override
  bool isValidKey(Object? o) => o is UsersRecord;
}
