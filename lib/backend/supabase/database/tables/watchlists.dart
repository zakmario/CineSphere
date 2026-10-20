import '../database.dart';

class WatchlistsTable extends SupabaseTable<WatchlistsRow> {
  @override
  String get tableName => 'watchlists';

  @override
  WatchlistsRow createRow(Map<String, dynamic> data) => WatchlistsRow(data);
}

class WatchlistsRow extends SupabaseDataRow {
  WatchlistsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => WatchlistsTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get userId => getField<String>('user_id')!;
  set userId(String value) => setField<String>('user_id', value);

  String get name => getField<String>('name')!;
  set name(String value) => setField<String>('name', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  bool? get isPublic => getField<bool>('is_public');
  set isPublic(bool? value) => setField<bool>('is_public', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
