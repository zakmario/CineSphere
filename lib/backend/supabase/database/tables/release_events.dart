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

  String get mediaId => getField<String>('media_id')!;
  set mediaId(String value) => setField<String>('media_id', value);

  String get title => getField<String>('title')!;
  set title(String value) => setField<String>('title', value);

  DateTime get releaseAt => getField<DateTime>('release_at')!;
  set releaseAt(DateTime value) => setField<DateTime>('release_at', value);

  String? get platform => getField<String>('platform');
  set platform(String? value) => setField<String>('platform', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);
}
