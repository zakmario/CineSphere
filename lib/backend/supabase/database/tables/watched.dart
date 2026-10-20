import '../database.dart';

class WatchedTable extends SupabaseTable<WatchedRow> {
  @override
  String get tableName => 'watched';

  @override
  WatchedRow createRow(Map<String, dynamic> data) => WatchedRow(data);
}

class WatchedRow extends SupabaseDataRow {
  WatchedRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => WatchedTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get userId => getField<String>('user_id')!;
  set userId(String value) => setField<String>('user_id', value);

  String? get movieId => getField<String>('movie_id');
  set movieId(String? value) => setField<String>('movie_id', value);

  String? get seriesId => getField<String>('series_id');
  set seriesId(String? value) => setField<String>('series_id', value);

  int? get episodeId => getField<int>('episode_id');
  set episodeId(int? value) => setField<int>('episode_id', value);

  DateTime? get watchedAt => getField<DateTime>('watched_at');
  set watchedAt(DateTime? value) => setField<DateTime>('watched_at', value);
}
