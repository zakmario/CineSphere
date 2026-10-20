import '../database.dart';

class SeriesTable extends SupabaseTable<SeriesRow> {
  @override
  String get tableName => 'series';

  @override
  SeriesRow createRow(Map<String, dynamic> data) => SeriesRow(data);
}

class SeriesRow extends SupabaseDataRow {
  SeriesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => SeriesTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  int get tmdbId => getField<int>('tmdb_id')!;
  set tmdbId(int value) => setField<int>('tmdb_id', value);

  String get title => getField<String>('title')!;
  set title(String value) => setField<String>('title', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  String? get posterUrl => getField<String>('poster_url');
  set posterUrl(String? value) => setField<String>('poster_url', value);

  String? get backdropUrl => getField<String>('backdrop_url');
  set backdropUrl(String? value) => setField<String>('backdrop_url', value);

  DateTime? get firstAirDate => getField<DateTime>('first_air_date');
  set firstAirDate(DateTime? value) =>
      setField<DateTime>('first_air_date', value);

  int? get numberOfSeasons => getField<int>('number_of_seasons');
  set numberOfSeasons(int? value) => setField<int>('number_of_seasons', value);

  int? get numberOfEpisodes => getField<int>('number_of_episodes');
  set numberOfEpisodes(int? value) =>
      setField<int>('number_of_episodes', value);

  double? get rating => getField<double>('rating');
  set rating(double? value) => setField<double>('rating', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
