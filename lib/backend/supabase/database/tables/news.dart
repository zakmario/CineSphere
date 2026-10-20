import '../database.dart';

class NewsTable extends SupabaseTable<NewsRow> {
  @override
  String get tableName => 'news';

  @override
  NewsRow createRow(Map<String, dynamic> data) => NewsRow(data);
}

class NewsRow extends SupabaseDataRow {
  NewsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => NewsTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String? get mediaId => getField<String>('media_id');
  set mediaId(String? value) => setField<String>('media_id', value);

  String get title => getField<String>('title')!;
  set title(String value) => setField<String>('title', value);

  String? get summary => getField<String>('summary');
  set summary(String? value) => setField<String>('summary', value);

  String? get imageUrl => getField<String>('image_url');
  set imageUrl(String? value) => setField<String>('image_url', value);

  DateTime? get publishedAt => getField<DateTime>('published_at');
  set publishedAt(DateTime? value) => setField<DateTime>('published_at', value);
}
