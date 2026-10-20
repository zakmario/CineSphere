import '../database.dart';

class MovieGenresTable extends SupabaseTable<MovieGenresRow> {
  @override
  String get tableName => 'movie_genres';

  @override
  MovieGenresRow createRow(Map<String, dynamic> data) => MovieGenresRow(data);
}

class MovieGenresRow extends SupabaseDataRow {
  MovieGenresRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MovieGenresTable();

  String get movieId => getField<String>('movie_id')!;
  set movieId(String value) => setField<String>('movie_id', value);

  int get genreId => getField<int>('genre_id')!;
  set genreId(int value) => setField<int>('genre_id', value);
}
