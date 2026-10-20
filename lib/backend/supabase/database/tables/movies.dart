import '../database.dart';

class MoviesTable extends SupabaseTable<MoviesRow> {
  @override
  String get tableName => 'movies';

  @override
  MoviesRow createRow(Map<String, dynamic> data) => MoviesRow(data);
}

class MoviesRow extends SupabaseDataRow {
  MoviesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MoviesTable();

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

  DateTime? get releaseDate => getField<DateTime>('release_date');
  set releaseDate(DateTime? value) => setField<DateTime>('release_date', value);

  int? get duration => getField<int>('duration');
  set duration(int? value) => setField<int>('duration', value);

  double? get rating => getField<double>('rating');
  set rating(double? value) => setField<double>('rating', value);

  String? get trailerUrl => getField<String>('trailer_url');
  set trailerUrl(String? value) => setField<String>('trailer_url', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
