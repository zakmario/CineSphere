import '../database.dart';

class GenresTable extends SupabaseTable<GenresRow> {
  @override
  String get tableName => 'genres';

  @override
  GenresRow createRow(Map<String, dynamic> data) => GenresRow(data);
}

class GenresRow extends SupabaseDataRow {
  GenresRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => GenresTable();

  int? get id => getField<int>('id');
  set id(int? value) => setField<int>('id', value);

  String get name => getField<String>('name')!;
  set name(String value) => setField<String>('name', value);
}
