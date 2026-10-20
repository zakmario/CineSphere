import '../database.dart';

class PlatformsTable extends SupabaseTable<PlatformsRow> {
  @override
  String get tableName => 'platforms';

  @override
  PlatformsRow createRow(Map<String, dynamic> data) => PlatformsRow(data);
}

class PlatformsRow extends SupabaseDataRow {
  PlatformsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => PlatformsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  String get name => getField<String>('name')!;
  set name(String value) => setField<String>('name', value);

  String? get logoUrl => getField<String>('logo_url');
  set logoUrl(String? value) => setField<String>('logo_url', value);
}
