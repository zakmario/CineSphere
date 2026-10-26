import '../database.dart';

class SearchHistoryTable extends SupabaseTable<SearchHistoryRow> {
  @override
  String get tableName => 'search_history';

  @override
  SearchHistoryRow createRow(Map<String, dynamic> data) =>
      SearchHistoryRow(data);
}

class SearchHistoryRow extends SupabaseDataRow {
  SearchHistoryRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => SearchHistoryTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get userId => getField<String>('user_id')!;
  set userId(String value) => setField<String>('user_id', value);

  String get query => getField<String>('query')!;
  set query(String value) => setField<String>('query', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
