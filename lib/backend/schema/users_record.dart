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

  // "username" field.
  String? _username;
  String get username => _username ?? '';
  bool hasUsername() => _username != null;

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

  // "preferences" field.
  PreferencesStruct? _preferences;
  PreferencesStruct get preferences => _preferences ?? PreferencesStruct();
  bool hasPreferences() => _preferences != null;

  // "uid" field.
  String? _uid;
  String get uid => _uid ?? '';
  bool hasUid() => _uid != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "photo_url" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  void _initializeFields() {
    _username = snapshotData['username'] as String?;
    _email = snapshotData['email'] as String?;
    _avatarUrl = snapshotData['avatarUrl'] as String?;
    _avatarData = snapshotData['avatarData'] as String?;
    _bio = snapshotData['bio'] as String?;
    _role = snapshotData['role'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
    _preferences = snapshotData['preferences'] is PreferencesStruct
        ? snapshotData['preferences']
        : PreferencesStruct.maybeFromMap(snapshotData['preferences']);
    _uid = snapshotData['uid'] as String?;
    _createdTime = snapshotData['created_time'] as DateTime?;
    _displayName = snapshotData['display_name'] as String?;
    _photoUrl = snapshotData['photo_url'] as String?;
    _phoneNumber = snapshotData['phone_number'] as String?;
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
  String? username,
  String? email,
  String? avatarUrl,
  String? avatarData,
  String? bio,
  String? role,
  DateTime? createdAt,
  DateTime? updatedAt,
  PreferencesStruct? preferences,
  String? uid,
  DateTime? createdTime,
  String? displayName,
  String? photoUrl,
  String? phoneNumber,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'avatarData': avatarData,
      'bio': bio,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'preferences': PreferencesStruct().toMap(),
      'uid': uid,
      'created_time': createdTime,
      'display_name': displayName,
      'photo_url': photoUrl,
      'phone_number': phoneNumber,
    }.withoutNulls,
  );

  // Handle nested data for "preferences" field.
  addPreferencesStructData(firestoreData, preferences, 'preferences');

  return firestoreData;
}

class UsersRecordDocumentEquality implements Equality<UsersRecord> {
  const UsersRecordDocumentEquality();

  @override
  bool equals(UsersRecord? e1, UsersRecord? e2) {
    return e1?.username == e2?.username &&
        e1?.email == e2?.email &&
        e1?.avatarUrl == e2?.avatarUrl &&
        e1?.avatarData == e2?.avatarData &&
        e1?.bio == e2?.bio &&
        e1?.role == e2?.role &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt &&
        e1?.preferences == e2?.preferences &&
        e1?.uid == e2?.uid &&
        e1?.createdTime == e2?.createdTime &&
        e1?.displayName == e2?.displayName &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.phoneNumber == e2?.phoneNumber;
  }

  @override
  int hash(UsersRecord? e) => const ListEquality().hash([
        e?.username,
        e?.email,
        e?.avatarUrl,
        e?.avatarData,
        e?.bio,
        e?.role,
        e?.createdAt,
        e?.updatedAt,
        e?.preferences,
        e?.uid,
        e?.createdTime,
        e?.displayName,
        e?.photoUrl,
        e?.phoneNumber
      ]);

  @override
  bool isValidKey(Object? o) => o is UsersRecord;
}
