// Faux Firestore : les classes de cloud_firestore sont « sealed ».
// ignore_for_file: subtype_of_sealed_class

import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:cine_sphere/flutter_flow/custom_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

typedef _Json = Map<String, dynamic>;

class _Doc extends Fake implements QueryDocumentSnapshot<_Json> {
  _Doc(this.id, this._data);

  @override
  final String id;
  final _Json _data;

  @override
  _Json data() => _data;
}

class _Snapshot extends Fake implements QuerySnapshot<_Json> {
  _Snapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<_Json>> docs;
}

/// Collection Firestore en mémoire : where (égalité, ≥), orderBy, limit et
/// startAfterDocument suffisent à UpcomingReleasesList. Chaque get() est
/// noté dans [log].
class _FakeQuery extends Fake implements CollectionReference<_Json> {
  _FakeQuery(
    this._docs,
    this.log, {
    List<bool Function(_Json)> filters = const [],
    String? order,
    int? limit,
    String? after,
  })  : _filters = filters,
        _order = order,
        _limit = limit,
        _after = after;

  final List<_Doc> _docs;
  final List<String> log;
  final List<bool Function(_Json)> _filters;
  final String? _order;
  final int? _limit;
  final String? _after;

  _FakeQuery _copy({
    List<bool Function(_Json)>? filters,
    String? order,
    int? limit,
    String? after,
  }) =>
      _FakeQuery(_docs, log,
          filters: filters ?? _filters,
          order: order ?? _order,
          limit: limit ?? _limit,
          after: after ?? _after);

  @override
  Query<_Json> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) =>
      _copy(filters: [
        ..._filters,
        (data) {
          final value = data[field];
          if (isEqualTo != null && value != isEqualTo) {
            return false;
          }
          if (isGreaterThanOrEqualTo is Timestamp &&
              (value as Timestamp).compareTo(isGreaterThanOrEqualTo) < 0) {
            return false;
          }
          return true;
        },
      ]);

  @override
  Query<_Json> orderBy(Object field, {bool descending = false}) =>
      _copy(order: field as String);

  @override
  Query<_Json> limit(int limit) => _copy(limit: limit);

  @override
  Query<_Json> startAfterDocument(DocumentSnapshot documentSnapshot) =>
      _copy(after: documentSnapshot.id);

  @override
  Future<QuerySnapshot<_Json>> get([GetOptions? options]) async {
    log.add('get${_after == null ? '' : ' après $_after'}');
    var docs = _docs.where((d) => _filters.every((f) => f(d.data()))).toList();
    if (_order != null) {
      docs.sort((a, b) =>
          (a.data()[_order] as Timestamp).compareTo(b.data()[_order]));
    }
    if (_after != null) {
      docs = docs.skipWhile((d) => d.id != _after).skip(1).toList();
    }
    return _Snapshot(docs.take(_limit ?? docs.length).toList());
  }
}

class _ReleasesService extends FakeCineFirebaseService {
  _FakeQuery? releases;

  @override
  CollectionReference<_Json> col(String name) => name == 'releaseEvents' &&
          releases != null
      ? releases!
      : throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
}

void main() {
  late _ReleasesService remote;
  late FakeNotifier notifier;
  late List<String> log;
  final now = DateTime.now();

  _Doc event(String id, String key, DateTime at,
      {String title = 'Sortie', String? platform}) {
    final media = parseMediaKey(key)!;
    return _Doc(id, {
      'mediaType': media.type,
      'tmdbId': media.tmdbId,
      'title': 'Titre $key',
      'releaseDate': Timestamp.fromDate(at),
      'platform': platform,
    });
  }

  DateTime inDays(int days, [int hour = 20]) =>
      DateTime(now.year, now.month, now.day + days, hour);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    log = [];
    remote = _ReleasesService();
    notifier = FakeNotifier();
    CineFirebaseService.debugInstance = remote;
    CineNotificationService.debugInstance = CineNotificationService(
      notifier: notifier,
      store: FakeNotificationStore(),
      local: MemoryLocalDb(),
      remote: remote,
    );
  });

  tearDown(() {
    CineFirebaseService.debugInstance = null;
    CineNotificationService.debugInstance = null;
  });

  void releases(List<_Doc> docs) => remote.releases = _FakeQuery(docs, log);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, UpcomingReleasesList list,
      {Size size = const Size(800, 1600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: list)));
    await settle(tester);
  }

  testWidgets('sorties à venir groupées par jour, passées exclues',
      (tester) async {
    releases([
      event('old', 'movie_1', now.subtract(const Duration(days: 1))),
      event('b', 'movie_2', inDays(2, 21), platform: 'Netflix'),
      event('a', 'movie_3', inDays(2, 18)),
      event('c', 'series_4', inDays(5)),
    ]);
    await pump(tester, const UpcomingReleasesList());

    expect(find.text('Titre movie_1'), findsNothing);
    final titles = tester
        .widgetList<Text>(find.textContaining('Titre '))
        .map((t) => t.data)
        .where((t) => !t!.contains(" • ")) // sous-titres exclus
        .toList();
    expect(titles, ['Titre movie_3', 'Titre movie_2', 'Titre series_4']);
    // Un en-tête par jour.
    expect(find.text(formatReleaseDate(inDays(2))), findsOneWidget);
    expect(find.text(formatReleaseDate(inDays(5))), findsOneWidget);
    expect(find.textContaining('Netflix'), findsOneWidget);
    expect(find.byType(FadeSlideIn), findsNWidgets(3));
  });

  testWidgets('pagination au scroll', (tester) async {
    releases(
        [for (var i = 0; i < 8; i++) event('e$i', 'movie_$i', inDays(i + 1))]);
    await pump(tester, const UpcomingReleasesList(pageSize: 5),
        size: const Size(400, 400));
    expect(log, ['get']);

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await settle(tester);
    expect(log, ['get', 'get après e4']);
    await tester.scrollUntilVisible(find.text('Titre movie_7'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Titre movie_7'), findsOneWidget);
  });

  testWidgets('fiche d\'un titre : ses sorties seulement, tap', (tester) async {
    releases([
      event('a', 'movie_550', inDays(1)),
      event('b', 'movie_2', inDays(1)),
    ]);
    final taps = <String>[];
    await pump(
        tester,
        UpcomingReleasesList(
            mediaId: 'movie_550', onItemTap: (id) async => taps.add(id)));

    expect(find.text('Titre movie_2'), findsNothing);
    await tester.tap(find.text('Titre movie_550'));
    expect(taps, ['movie_550']);
  });

  testWidgets('cloche : rappel programmé avant la sortie, puis supprimé',
      (tester) async {
    final releaseAt = inDays(3);
    releases([event('e1', 'movie_1', releaseAt)]);
    await pump(tester, const UpcomingReleasesList(reminderMinutesBefore: 30));

    await tester.tap(find.byTooltip('Me le rappeler'));
    await settle(tester);
    final scheduled = notifier.scheduled[notificationIdFromString('e1')]!;
    expect(scheduled.at, releaseAt.subtract(const Duration(minutes: 30)));
    expect(scheduled.title, 'Titre movie_1');
    expect(find.textContaining('Rappel programmé'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer le rappel'));
    await settle(tester);
    expect(notifier.scheduled, isEmpty);
    expect(find.text('Rappel supprimé'), findsOneWidget);
  });

  testWidgets('erreur puis réessayer ; liste vide', (tester) async {
    await pump(tester, const UpcomingReleasesList());
    expect(find.text('Impossible de charger le calendrier.'), findsOneWidget);

    releases([]);
    await tester.tap(find.text('Impossible de charger le calendrier.'));
    await settle(tester);
    expect(find.text('Aucune sortie prévue pour le moment.'), findsOneWidget);
  });

  testWidgets('chargement : squelette', (tester) async {
    releases([event('e1', 'movie_1', inDays(1))]);
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UpcomingReleasesList())));
    expect(find.byType(CineSkeleton), findsOneWidget);
    await settle(tester);
    expect(find.byType(CineSkeleton), findsNothing);
  });
}
