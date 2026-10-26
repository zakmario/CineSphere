import '../database.dart';

class ReleaseEventsTable extends SupabaseTable<ReleaseEventsRow> {
  @override
  String get tableName => 'release_events';

  @override
  ReleaseEventsRow createRow(Map<String, dynamic> data) =>
      ReleaseEventsRow(data);
}

class ReleaseEventsRow extends SupabaseDataRow {
  ReleaseEventsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ReleaseEventsTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String? get mediaId => getField<String>('media_id');
  set mediaId(String? value) => setField<String>('media_id', value);

  String get title => getField<String>('title')!;
  set title(String value) => setField<String>('title', value);

  DateTime get releaseAt => getField<DateTime>('release_at')!;
  set releaseAt(DateTime value) => setField<DateTime>('release_at', value);

  String? get platform => getField<String>('platform');
  set platform(String? value) => setField<String>('platform', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  String? get movieId => getField<String>('movie_id');
  set movieId(String? value) => setField<String>('movie_id', value);

  String? get seriesId => getField<String>('series_id');
  set seriesId(String? value) => setField<String>('series_id', value);

  int? get seasonNumber => getField<int>('season_number');
  set seasonNumber(int? value) => setField<int>('season_number', value);

  int? get episodeNumber => getField<int>('episode_number');
  set episodeNumber(int? value) => setField<int>('episode_number', value);

  DateTime? get releaseDate => getField<DateTime>('release_date');
  set releaseDate(DateTime? value) => setField<DateTime>('release_date', value);
}
