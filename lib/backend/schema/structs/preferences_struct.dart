// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart' hide Type;

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PreferencesStruct extends FFFirebaseStruct {
  PreferencesStruct({
    List<int>? favoriteGenres,
    List<String>? favoritePlatforms,
    List<String>? contentTypes,
    bool? notificationsEnabled,
    bool? notifyReleases,
    bool? notifyFavoriteSeries,
    String? reminderTime,
    String? themeMode,
    bool? onboardingCompleted,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _favoriteGenres = favoriteGenres,
        _favoritePlatforms = favoritePlatforms,
        _contentTypes = contentTypes,
        _notificationsEnabled = notificationsEnabled,
        _notifyReleases = notifyReleases,
        _notifyFavoriteSeries = notifyFavoriteSeries,
        _reminderTime = reminderTime,
        _themeMode = themeMode,
        _onboardingCompleted = onboardingCompleted,
        super(firestoreUtilData);

  // "favoriteGenres" field.
  List<int>? _favoriteGenres;
  List<int> get favoriteGenres => _favoriteGenres ?? const [];
  set favoriteGenres(List<int>? val) => _favoriteGenres = val;

  void updateFavoriteGenres(Function(List<int>) updateFn) {
    updateFn(_favoriteGenres ??= []);
  }

  bool hasFavoriteGenres() => _favoriteGenres != null;

  // "favoritePlatforms" field.
  List<String>? _favoritePlatforms;
  List<String> get favoritePlatforms => _favoritePlatforms ?? const [];
  set favoritePlatforms(List<String>? val) => _favoritePlatforms = val;

  void updateFavoritePlatforms(Function(List<String>) updateFn) {
    updateFn(_favoritePlatforms ??= []);
  }

  bool hasFavoritePlatforms() => _favoritePlatforms != null;

  // "contentTypes" field.
  List<String>? _contentTypes;
  List<String> get contentTypes => _contentTypes ?? const [];
  set contentTypes(List<String>? val) => _contentTypes = val;

  void updateContentTypes(Function(List<String>) updateFn) {
    updateFn(_contentTypes ??= []);
  }

  bool hasContentTypes() => _contentTypes != null;

  // "notificationsEnabled" field.
  bool? _notificationsEnabled;
  bool get notificationsEnabled => _notificationsEnabled ?? false;
  set notificationsEnabled(bool? val) => _notificationsEnabled = val;

  bool hasNotificationsEnabled() => _notificationsEnabled != null;

  // "notifyReleases" field.
  bool? _notifyReleases;
  bool get notifyReleases => _notifyReleases ?? false;
  set notifyReleases(bool? val) => _notifyReleases = val;

  bool hasNotifyReleases() => _notifyReleases != null;

  // "notifyFavoriteSeries" field.
  bool? _notifyFavoriteSeries;
  bool get notifyFavoriteSeries => _notifyFavoriteSeries ?? false;
  set notifyFavoriteSeries(bool? val) => _notifyFavoriteSeries = val;

  bool hasNotifyFavoriteSeries() => _notifyFavoriteSeries != null;

  // "reminderTime" field.
  String? _reminderTime;
  String get reminderTime => _reminderTime ?? '';
  set reminderTime(String? val) => _reminderTime = val;

  bool hasReminderTime() => _reminderTime != null;

  // "themeMode" field.
  String? _themeMode;
  String get themeMode => _themeMode ?? '';
  set themeMode(String? val) => _themeMode = val;

  bool hasThemeMode() => _themeMode != null;

  // "onboardingCompleted" field.
  bool? _onboardingCompleted;
  bool get onboardingCompleted => _onboardingCompleted ?? false;
  set onboardingCompleted(bool? val) => _onboardingCompleted = val;

  bool hasOnboardingCompleted() => _onboardingCompleted != null;

  static PreferencesStruct fromMap(Map<String, dynamic> data) =>
      PreferencesStruct(
        favoriteGenres: getDataList(data['favoriteGenres']),
        favoritePlatforms: getDataList(data['favoritePlatforms']),
        contentTypes: getDataList(data['contentTypes']),
        notificationsEnabled: data['notificationsEnabled'] as bool?,
        notifyReleases: data['notifyReleases'] as bool?,
        notifyFavoriteSeries: data['notifyFavoriteSeries'] as bool?,
        reminderTime: data['reminderTime'] as String?,
        themeMode: data['themeMode'] as String?,
        onboardingCompleted: data['onboardingCompleted'] as bool?,
      );

  static PreferencesStruct? maybeFromMap(dynamic data) => data is Map
      ? PreferencesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'favoriteGenres': _favoriteGenres,
        'favoritePlatforms': _favoritePlatforms,
        'contentTypes': _contentTypes,
        'notificationsEnabled': _notificationsEnabled,
        'notifyReleases': _notifyReleases,
        'notifyFavoriteSeries': _notifyFavoriteSeries,
        'reminderTime': _reminderTime,
        'themeMode': _themeMode,
        'onboardingCompleted': _onboardingCompleted,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'favoriteGenres': serializeParam(
          _favoriteGenres,
          ParamType.int,
          isList: true,
        ),
        'favoritePlatforms': serializeParam(
          _favoritePlatforms,
          ParamType.String,
          isList: true,
        ),
        'contentTypes': serializeParam(
          _contentTypes,
          ParamType.String,
          isList: true,
        ),
        'notificationsEnabled': serializeParam(
          _notificationsEnabled,
          ParamType.bool,
        ),
        'notifyReleases': serializeParam(
          _notifyReleases,
          ParamType.bool,
        ),
        'notifyFavoriteSeries': serializeParam(
          _notifyFavoriteSeries,
          ParamType.bool,
        ),
        'reminderTime': serializeParam(
          _reminderTime,
          ParamType.String,
        ),
        'themeMode': serializeParam(
          _themeMode,
          ParamType.String,
        ),
        'onboardingCompleted': serializeParam(
          _onboardingCompleted,
          ParamType.bool,
        ),
      }.withoutNulls;

  static PreferencesStruct fromSerializableMap(Map<String, dynamic> data) =>
      PreferencesStruct(
        favoriteGenres: deserializeParam<int>(
          data['favoriteGenres'],
          ParamType.int,
          true,
        ),
        favoritePlatforms: deserializeParam<String>(
          data['favoritePlatforms'],
          ParamType.String,
          true,
        ),
        contentTypes: deserializeParam<String>(
          data['contentTypes'],
          ParamType.String,
          true,
        ),
        notificationsEnabled: deserializeParam(
          data['notificationsEnabled'],
          ParamType.bool,
          false,
        ),
        notifyReleases: deserializeParam(
          data['notifyReleases'],
          ParamType.bool,
          false,
        ),
        notifyFavoriteSeries: deserializeParam(
          data['notifyFavoriteSeries'],
          ParamType.bool,
          false,
        ),
        reminderTime: deserializeParam(
          data['reminderTime'],
          ParamType.String,
          false,
        ),
        themeMode: deserializeParam(
          data['themeMode'],
          ParamType.String,
          false,
        ),
        onboardingCompleted: deserializeParam(
          data['onboardingCompleted'],
          ParamType.bool,
          false,
        ),
      );

  @override
  String toString() => 'PreferencesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is PreferencesStruct &&
        listEquality.equals(favoriteGenres, other.favoriteGenres) &&
        listEquality.equals(favoritePlatforms, other.favoritePlatforms) &&
        listEquality.equals(contentTypes, other.contentTypes) &&
        notificationsEnabled == other.notificationsEnabled &&
        notifyReleases == other.notifyReleases &&
        notifyFavoriteSeries == other.notifyFavoriteSeries &&
        reminderTime == other.reminderTime &&
        themeMode == other.themeMode &&
        onboardingCompleted == other.onboardingCompleted;
  }

  @override
  int get hashCode => const ListEquality().hash([
        const ListEquality().hash(favoriteGenres),
        const ListEquality().hash(favoritePlatforms),
        const ListEquality().hash(contentTypes),
        notificationsEnabled,
        notifyReleases,
        notifyFavoriteSeries,
        reminderTime,
        themeMode,
        onboardingCompleted
      ]);
}

PreferencesStruct createPreferencesStruct({
  bool? notificationsEnabled,
  bool? notifyReleases,
  bool? notifyFavoriteSeries,
  String? reminderTime,
  String? themeMode,
  bool? onboardingCompleted,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    PreferencesStruct(
      notificationsEnabled: notificationsEnabled,
      notifyReleases: notifyReleases,
      notifyFavoriteSeries: notifyFavoriteSeries,
      reminderTime: reminderTime,
      themeMode: themeMode,
      onboardingCompleted: onboardingCompleted,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

PreferencesStruct? updatePreferencesStruct(
  PreferencesStruct? preferences, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    preferences
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addPreferencesStructData(
  Map<String, dynamic> firestoreData,
  PreferencesStruct? preferences,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (preferences == null) {
    return;
  }
  if (preferences.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && preferences.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final preferencesData =
      getPreferencesFirestoreData(preferences, forFieldValue);
  final nestedData =
      preferencesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = preferences.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getPreferencesFirestoreData(
  PreferencesStruct? preferences, [
  bool forFieldValue = false,
]) {
  if (preferences == null) {
    return {};
  }
  final firestoreData = mapToFirestore(preferences.toMap());

  // Add any Firestore field values
  mapToFirestore(preferences.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getPreferencesListFirestoreData(
  List<PreferencesStruct>? preferencess,
) =>
    preferencess?.map((e) => getPreferencesFirestoreData(e, true)).toList() ??
    [];
