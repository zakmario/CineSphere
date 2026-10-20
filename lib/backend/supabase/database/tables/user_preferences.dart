import '../database.dart';

class UserPreferencesTable extends SupabaseTable<UserPreferencesRow> {
  @override
  String get tableName => 'user_preferences';

  @override
  UserPreferencesRow createRow(Map<String, dynamic> data) =>
      UserPreferencesRow(data);
}

class UserPreferencesRow extends SupabaseDataRow {
  UserPreferencesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => UserPreferencesTable();

  String get userId => getField<String>('user_id')!;
  set userId(String value) => setField<String>('user_id', value);

  List<int> get favoriteGenres => getListField<int>('favorite_genres');
  set favoriteGenres(List<int>? value) =>
      setListField<int>('favorite_genres', value);

  List<String> get favoritePlatforms =>
      getListField<String>('favorite_platforms');
  set favoritePlatforms(List<String>? value) =>
      setListField<String>('favorite_platforms', value);

  List<String> get contentTypes => getListField<String>('content_types');
  set contentTypes(List<String>? value) =>
      setListField<String>('content_types', value);

  bool? get notificationsEnabled => getField<bool>('notifications_enabled');
  set notificationsEnabled(bool? value) =>
      setField<bool>('notifications_enabled', value);

  bool? get notifyReleases => getField<bool>('notify_releases');
  set notifyReleases(bool? value) => setField<bool>('notify_releases', value);

  bool? get notifyFavoriteSeries => getField<bool>('notify_favorite_series');
  set notifyFavoriteSeries(bool? value) =>
      setField<bool>('notify_favorite_series', value);

  PostgresTime? get reminderTime => getField<PostgresTime>('reminder_time');
  set reminderTime(PostgresTime? value) =>
      setField<PostgresTime>('reminder_time', value);

  String? get themeMode => getField<String>('theme_mode');
  set themeMode(String? value) => setField<String>('theme_mode', value);

  bool? get onboardingCompleted => getField<bool>('onboarding_completed');
  set onboardingCompleted(bool? value) =>
      setField<bool>('onboarding_completed', value);

  DateTime? get updatedAt => getField<DateTime>('updated_at');
  set updatedAt(DateTime? value) => setField<DateTime>('updated_at', value);
}
