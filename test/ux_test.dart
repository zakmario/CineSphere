import 'dart:async';

import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/widgets/cine_skeleton.dart';
import 'package:cine_sphere/custom_code/widgets/fade_slide_in.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

/// Première page retenue jusqu'à [release]. Le Completer est créé au premier
/// appel, dans la zone du test (sinon pump ne le voit pas se terminer).
class _SlowStore extends FakeNotificationStore {
  Completer<void>? _gate;

  void release() => _gate!.complete();

  @override
  Future<NotificationPage> fetchPage(
      {Object? after, int pageSize = 20, required DateTime now}) async {
    await (_gate ??= Completer<void>()).future;
    return super.fetchPage(after: after, pageSize: pageSize, now: now);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: Scaffold(body: child),
          ),
        ),
      );

  double opacityOf(WidgetTester tester, Finder finder) => tester
      .widget<FadeTransition>(find
          .ancestor(of: finder, matching: find.byType(FadeTransition))
          .first)
      .opacity
      .value;

  group('CineSkeleton', () {
    for (final variant in [...kSkeletonVariants, null, 'inconnu']) {
      testWidgets('variante $variant', (tester) async {
        await tester.pumpWidget(app(CineSkeleton(variant: variant)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byType(SkeletonBox), findsWidgets);
        expect(find.bySemanticsLabel('Chargement en cours'), findsOneWidget);
        expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isTrue);
      });
    }

    testWidgets('nombre d\'éléments et réduction des animations',
        (tester) async {
      await tester.pumpWidget(app(
          const CineSkeleton(variant: 'list', itemCount: 3),
          reduceMotion: true));
      // 3 lignes : vignette + 2 traits.
      expect(find.byType(SkeletonBox), findsNWidgets(9));
      expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isFalse);
    });

    testWidgets('hauteur limitée : pas de débordement', (tester) async {
      await tester.pumpWidget(app(const SizedBox(
          height: 120, child: CineSkeleton(variant: 'grid', itemCount: 12))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('FadeSlideIn', () {
    testWidgets('fondu puis visible, en cascade selon l\'index',
        (tester) async {
      await tester.pumpWidget(app(const Column(children: [
        FadeSlideIn(index: 0, child: Text('premier')),
        FadeSlideIn(index: 5, child: Text('sixième')),
      ])));
      expect(opacityOf(tester, find.text('premier')), 0);

      await tester.pump(const Duration(milliseconds: 200));
      final first = opacityOf(tester, find.text('premier'));
      final sixth = opacityOf(tester, find.text('sixième'));
      expect(first, greaterThan(0));
      expect(sixth, lessThan(first));

      await tester.pump(const Duration(seconds: 1));
      expect(opacityOf(tester, find.text('premier')), 1);
      expect(opacityOf(tester, find.text('sixième')), 1);
    });

    testWidgets(
        'réduction des animations ou désactivé : visible tout de '
        'suite', (tester) async {
      await tester.pumpWidget(app(const FadeSlideIn(index: 3, child: Text('a')),
          reduceMotion: true));
      expect(opacityOf(tester, find.text('a')), 1);

      await tester
          .pumpWidget(app(const FadeSlideIn(enabled: false, child: Text('b'))));
      expect(opacityOf(tester, find.text('b')), 1);
    });
  });

  group('cineStateSwitcher', () {
    Widget switcher(String state, {bool reduceMotion = false}) => app(
        Builder(
            builder: (context) =>
                cineStateSwitcher(context, state, Text('état $state'))),
        reduceMotion: reduceMotion);

    testWidgets('fondu enchaîné entre deux états', (tester) async {
      await tester.pumpWidget(switcher('chargement'));
      await tester.pumpWidget(switcher('liste'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('état chargement'), findsOneWidget);
      expect(find.text('état liste'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('état chargement'), findsNothing);
      expect(find.text('état liste'), findsOneWidget);
    });

    testWidgets('réduction des animations : changement immédiat',
        (tester) async {
      await tester.pumpWidget(switcher('chargement', reduceMotion: true));
      await tester.pumpWidget(switcher('liste', reduceMotion: true));
      await tester.pump();
      expect(find.text('état chargement'), findsNothing);
    });
  });

  group('dans les écrans', () {
    late _SlowStore store;
    final now = DateTime(2026, 11, 10, 9);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = _SlowStore();
      final remote = FakeCineFirebaseService();
      CineNotificationService.debugInstance = CineNotificationService(
        notifier: FakeNotifier(),
        store: store,
        local: MemoryLocalDb(now: () => now),
        remote: remote,
        now: () => now,
      );
    });

    tearDown(() => CineNotificationService.debugInstance = null);

    testWidgets('Notifications : squelette puis liste animée', (tester) async {
      store.add(notificationEntry('e1', at: DateTime(2026, 11, 10, 8)));
      await tester.pumpWidget(app(const NotificationsCenter()));
      await tester.pump();
      expect(find.byType(CineSkeleton), findsOneWidget);

      store.release();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(CineSkeleton), findsNothing);
      expect(find.text('Titre e1'), findsOneWidget);
      expect(
          find.ancestor(
              of: find.text('Titre e1'), matching: find.byType(FadeSlideIn)),
          findsOneWidget);
    });

    test('fiche ouverte depuis une notification : glisse du bas', () {
      expect(kNotificationOpenTransition.hasTransition, isTrue);
      expect(kNotificationOpenTransition.transitionType,
          PageTransitionType.bottomToTop);
    });
  });
}
