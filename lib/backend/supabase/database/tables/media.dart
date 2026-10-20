import '../database.dart';

class MediaTable extends SupabaseTable<MediaRow> {
  @override
  String get tableName => 'media';

  @override
  MediaRow createRow(Map<String, dynamic> data) => MediaRow(data);
}

class MediaRow extends SupabaseDataRow {
  MediaRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MediaTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get mediaType => getField<String>('media_type')!;
  set mediaType(String value) => setField<String>('media_type', value);

  String get title => getField<String>('title')!;
  set title(String value) => setField<String>('title', value);

  String? get overview => getField<String>('overview');
  set overview(String? value) => setField<String>('overview', value);

  String? get posterUrl => getField<String>('poster_url');
  set posterUrl(String? value) => setField<String>('poster_url', value);

  String? get backdropUrl => getField<String>('backdrop_url');
  set backdropUrl(String? value) => setField<String>('backdrop_url', value);

  DateTime? get releaseDate => getField<DateTime>('release_date');
  set releaseDate(DateTime? value) => setField<DateTime>('release_date', value);

  int? get runtimeMinutes => getField<int>('runtime_minutes');
  set runtimeMinutes(int? value) => setField<int>('runtime_minutes', value);

  int? get seasons => getField<int>('seasons');
  set seasons(int? value) => setField<int>('seasons', value);

  int? get episodes => getField<int>('episodes');
  set episodes(int? value) => setField<int>('episodes', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);

  double? get rating => getField<double>('rating');
  set rating(double? value) => setField<double>('rating', value);

  int? get popularity => getField<int>('popularity');
  set popularity(int? value) => setField<int>('popularity', value);

  List<String> get genres => getListField<String>('genres');
  set genres(List<String>? value) => setListField<String>('genres', value);

  List<String> get platforms => getListField<String>('platforms');
  set platforms(List<String>? value) =>
      setListField<String>('platforms', value);

  String? get trailerUrl => getField<String>('trailer_url');
  set trailerUrl(String? value) => setField<String>('trailer_url', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
