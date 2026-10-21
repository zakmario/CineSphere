import '../database.dart';

class WatchlistItemsTable extends SupabaseTable<WatchlistItemsRow> {
  @override
  String get tableName => 'watchlist_items';

  @override
  WatchlistItemsRow createRow(Map<String, dynamic> data) =>
      WatchlistItemsRow(data);
}

class WatchlistItemsRow extends SupabaseDataRow {
  WatchlistItemsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => WatchlistItemsTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get watchlistId => getField<String>('watchlist_id')!;
  set watchlistId(String value) => setField<String>('watchlist_id', value);

  String? get movieId => getField<String>('movie_id');
  set movieId(String? value) => setField<String>('movie_id', value);

  String? get seriesId => getField<String>('series_id');
  set seriesId(String? value) => setField<String>('series_id', value);

  String? get mediaId => getField<String>('media_id');
  set mediaId(String? value) => setField<String>('media_id', value);

  DateTime? get addedAt => getField<DateTime>('added_at');
  set addedAt(DateTime? value) => setField<DateTime>('added_at', value);
}
