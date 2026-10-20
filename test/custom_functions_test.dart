import 'package:cine_sphere/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.now();
  DateTime inDays(int days) =>
      DateTime(today.year, today.month, today.day + days, 20, 30);

  group('formatRuntime', () {
    test('heures et minutes', () => expect(formatRuntime(148), '2 h 28 min'));
    test('minutes seules', () => expect(formatRuntime(45), '45 min'));
    test('heures pile', () => expect(formatRuntime(120), '2 h'));
    test('minutes < 10 complétées', () => expect(formatRuntime(65), '1 h 05 min'));
    test('valeur absente', () {
      expect(formatRuntime(null), '');
      expect(formatRuntime(0), '');
    });
  });

  group('formatReleaseDate', () {
    test('en français', () {
      expect(formatReleaseDate(DateTime(2010, 7, 16)), '16 juillet 2010');
      expect(formatReleaseDate(DateTime(2024, 2, 1)), '1 février 2024');
    });
    test('date absente', () => expect(formatReleaseDate(null), 'Date inconnue'));
  });

  group('daysUntil / isReleaseSoon / releaseCountdownLabel', () {
    test('aujourd\'hui, demain, plus tard, passé', () {
      expect(daysUntil(inDays(0)), 0);
      expect(daysUntil(inDays(1)), 1);
      expect(daysUntil(inDays(10)), 10);
      expect(daysUntil(inDays(-3)), -3);
    });

    test('isReleaseSoon respecte la fenêtre', () {
      expect(isReleaseSoon(inDays(3), 7), isTrue);
      expect(isReleaseSoon(inDays(0), 0), isTrue);
      expect(isReleaseSoon(inDays(8), 7), isFalse);
      expect(isReleaseSoon(inDays(-1), 7), isFalse);
      expect(isReleaseSoon(null, 7), isFalse);
    });

    test('libellés', () {
      expect(releaseCountdownLabel(inDays(0)), "Aujourd'hui");
      expect(releaseCountdownLabel(inDays(1)), 'Demain');
      expect(releaseCountdownLabel(inDays(5)), 'Dans 5 jours');
      expect(releaseCountdownLabel(inDays(-2)), 'Sorti');
      expect(releaseCountdownLabel(null), 'Date à venir');
    });
  });

  group('libellés catalogue', () {
    test('mediaTypeLabel', () {
      expect(mediaTypeLabel('movie'), 'Film');
      expect(mediaTypeLabel('series'), 'Série');
      expect(mediaTypeLabel(null), 'Tous');
    });

    test('statusLabel', () {
      expect(statusLabel('upcoming'), 'À venir');
      expect(statusLabel('ended'), 'Terminée');
      expect(statusLabel('inconnu'), '');
    });

    test('seasonsLabel accorde le pluriel', () {
      expect(seasonsLabel(1, 1), '1 saison • 1 épisode');
      expect(seasonsLabel(5, 62), '5 saisons • 62 épisodes');
      expect(seasonsLabel(null, null), '');
    });
  });

  group('notes', () {
    test('ratingLabel', () {
      expect(ratingLabel(8.75), '8.8');
      expect(ratingLabel(0), '—');
      expect(ratingLabel(null), '—');
    });

    test('ratingColor par palier', () {
      expect(ratingColor(8.0), const Color(0xFF2E7D32));
      expect(ratingColor(6.0), const Color(0xFFF9A825));
      expect(ratingColor(3.0), const Color(0xFFC62828));
      expect(ratingColor(null), const Color(0xFF9E9E9E));
    });
  });

  group('notificationIdFromString', () {
    test('stable, positif et sur 31 bits', () {
      const key = '7f1c2a9e-1b2c-4d5e-8f90-123456789abc';
      final id = notificationIdFromString(key);
      expect(notificationIdFromString(key), id);
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('valeur FNV-1a connue', () {
      // FNV-1a 32 bits de "a" = 0xE40C292C, masqué sur 31 bits.
      expect(notificationIdFromString('a'), 0xE40C292C & 0x7FFFFFFF);
    });

    test('clés différentes -> ids différents', () {
      expect(
        notificationIdFromString('event-1'),
        isNot(notificationIdFromString('event-2')),
      );
    });
  });
}
