import '../database.dart';

class SeriesGenresTable extends SupabaseTable<SeriesGenresRow> {
  @override
  String get tableName => 'series_genres';

  @override
  SeriesGenresRow createRow(Map<String, dynamic> data) => SeriesGenresRow(data);
}

class SeriesGenresRow extends SupabaseDataRow {
  SeriesGenresRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => SeriesGenresTable();

  String get seriesId => getField<String>('series_id')!;
  set seriesId(String value) => setField<String>('series_id', value);

  int get genreId => getField<int>('genre_id')!;
  set genreId(int value) => setField<int>('genre_id', value);
}
