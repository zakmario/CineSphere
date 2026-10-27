// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/cine_notification_service.dart';
import '/custom_code/actions/firebase_service.dart';

/// Marque le walkthrough comme terminé et enregistre les genres préférés
/// (noms). Le walkthrough complet (plateformes, types de contenus,
/// notifications) passe par [OnboardingService.complete].
Future completeOnboarding(List<String> favoriteGenres) async {
  final service = OnboardingService.instance;
  final genres = await service.genres();
  final ids = {for (final g in genres) g.name: g.id};
  await service.complete(OnboardingChoices(
    genreIds: [
      for (final name in favoriteGenres)
        if (ids[name] != null) ids[name]!,
    ],
    genreNames: favoriteGenres,
  ));
}

// Clés shared_preferences.

/// Walkthrough vu sur cet appareil (gardé à la déconnexion).
const kOnboardingDoneKey = 'cs_onboarding_done';

/// Choix du walkthrough pas encore écrits dans le profil (hors connexion).
const kOnboardingPendingKey = 'cs_onboarding_pending';

/// Genres choisis, par nom (lus par HomeFeed, « Pour vous »).
const kFavoriteGenreNamesKey = 'cs_favorite_genres';

/// Visite guidée de la HomePage déjà faite.
const kHomeTourDoneKey = 'cs_home_tour_done';

const Duration kOnboardingTimeout = Duration(seconds: 8);

/// Genres TMDB proposés si Firestore ne répond pas.
const kFallbackGenres = [
  Genre(id: 28, name: 'Action'),
  Genre(id: 16, name: 'Animation'),
  Genre(id: 35, name: 'Comédie'),
  Genre(id: 18, name: 'Drame'),
  Genre(id: 14, name: 'Fantastique'),
  Genre(id: 27, name: 'Horreur'),
  Genre(id: 878, name: 'Science-fiction'),
  Genre(id: 53, name: 'Thriller'),
];

/// Plateformes proposées si Firestore ne répond pas (noms du seed).
const kFallbackPlatforms = [
  Platform(id: 8, name: 'Netflix'),
  Platform(id: 119, name: 'Prime Video'),
  Platform(id: 337, name: 'Disney+'),
  Platform(id: 350, name: 'Apple TV+'),
  Platform(id: 1899, name: 'Max'),
  Platform(id: 381, name: 'Canal+'),
];

/// Choix de l'écran Préférences du walkthrough.
class OnboardingChoices {
  const OnboardingChoices({
    this.genreIds = const [],
    this.genreNames = const [],
    this.platforms = const [],
    this.contentTypes = const [MediaType.movie, MediaType.series],
    this.notificationsEnabled = true,
  });

  /// Identifiants TMDB (comme `preferences.favoriteGenres`).
  final List<int> genreIds;
  final List<String> genreNames;
  final List<String> platforms;
  final List<MediaType> contentTypes;
  final bool notificationsEnabled;

  UserPreferences applyTo(UserPreferences prefs) => prefs.copyWith(
        favoriteGenres: genreIds,
        favoritePlatforms: platforms,
        contentTypes: contentTypes,
        notificationsEnabled: notificationsEnabled,
        onboardingCompleted: true,
      );

  factory OnboardingChoices.fromJson(Map<String, dynamic> json) =>
      OnboardingChoices(
        genreIds: [
          for (final id in json['genre_ids'] as List? ?? const [])
            if (id is num) id.toInt(),
        ],
        genreNames: [
          ...(json['genre_names'] as List? ?? const []).whereType<String>(),
        ],
        platforms: [
          ...(json['platforms'] as List? ?? const []).whereType<String>(),
        ],
        contentTypes: [
          for (final type in json['content_types'] as List? ?? const [])
            if (type is String) MediaType.fromValue(type),
        ],
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'genre_ids': genreIds,
        'genre_names': genreNames,
        'platforms': platforms,
        'content_types': contentTypes.map((t) => t.value).toList(),
        'notifications_enabled': notificationsEnabled,
      };
}

/// Walkthrough de première utilisation (section 6.1). Le flag « terminé »
/// est gardé sur l'appareil (`cs_onboarding_done` : rapide, hors connexion)
/// et dans `users/{uid}.preferences.onboardingCompleted` (pas de nouveau
/// walkthrough après une réinstallation).
class OnboardingService {
  OnboardingService(
      {CineFirebaseService? remote, CineNotificationService? notifications})
      : _remote = remote,
        _notifications = notifications;

  static OnboardingService? _instance;
  static OnboardingService? _override;

  static OnboardingService get instance =>
      _override ?? (_instance ??= OnboardingService());

  @visibleForTesting
  static set debugInstance(OnboardingService? service) => _override = service;

  final CineFirebaseService? _remote;
  final CineNotificationService? _notifications;

  CineFirebaseService get remote => _remote ?? CineFirebaseService.instance;
  CineNotificationService get notifications =>
      _notifications ?? CineNotificationService.instance;

  String? get _userId {
    try {
      return remote.currentUserId;
    } catch (_) {
      return null; // Firebase pas initialisé (tests de widgets).
    }
  }

  /// Genres du catalogue, ou [kFallbackGenres] hors connexion.
  Future<List<Genre>> genres() async {
    try {
      final genres = await remote.fetchGenres().timeout(kOnboardingTimeout);
      if (genres.isNotEmpty) {
        return genres;
      }
    } catch (_) {}
    return kFallbackGenres;
  }

  /// Plateformes du catalogue, ou [kFallbackPlatforms] hors connexion.
  Future<List<Platform>> platforms() async {
    try {
      final platforms =
          await remote.fetchPlatforms().timeout(kOnboardingTimeout);
      if (platforms.isNotEmpty) {
        return platforms;
      }
    } catch (_) {}
    return kFallbackPlatforms;
  }

  /// Vrai si le walkthrough a déjà été vu : l'appareil d'abord, puis le
  /// profil Firestore.
  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kOnboardingDoneKey) ?? false) {
      if (prefs.containsKey(kOnboardingPendingKey)) {
        unawaited(syncPending());
      }
      return true;
    }
    final saved = await currentPreferences();
    if (saved?.onboardingCompleted ?? false) {
      await prefs.setBool(kOnboardingDoneKey, true);
      // Visite guidée déjà proposée sur un autre appareil.
      await prefs.setBool(kHomeTourDoneKey, true);
      return true;
    }
    return false;
  }

  /// Préférences du profil (pour pré-cocher l'écran Préférences) ; null si
  /// déconnecté ou hors connexion.
  Future<UserPreferences?> currentPreferences() async {
    if (_userId == null) {
      return null;
    }
    try {
      return await remote.fetchPreferences().timeout(kOnboardingTimeout);
    } catch (e) {
      developer.log('currentPreferences', name: 'Onboarding', error: e);
      return null;
    }
  }

  /// Fin du walkthrough : flag et genres sur l'appareil tout de suite, puis
  /// profil Firestore (gardé pour plus tard si hors connexion) et réglages
  /// des notifications. Renvoie vrai si le profil est à jour.
  Future<bool> complete(OnboardingChoices choices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingDoneKey, true);
    await prefs.setStringList(kFavoriteGenreNamesKey, choices.genreNames);
    await prefs.setString(kOnboardingPendingKey, jsonEncode(choices.toJson()));

    final saved = await _push(prefs, choices, overwrite: true);
    try {
      await notifications.applyPreferences(
          saved ?? choices.applyTo(UserPreferences(userId: _userId ?? '')));
    } catch (e) {
      developer.log('notifications', name: 'Onboarding', error: e);
    }
    return saved != null;
  }

  /// Écrit dans le profil les choix restés sur l'appareil (walkthrough fini
  /// hors connexion). Renvoie vrai s'il ne reste rien à écrire.
  Future<bool> syncPending() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(kOnboardingPendingKey);
    if (text == null) {
      return true;
    }
    final OnboardingChoices choices;
    try {
      choices = OnboardingChoices.fromJson(
          Map<String, dynamic>.from(jsonDecode(text) as Map));
    } catch (_) {
      await prefs.remove(kOnboardingPendingKey);
      return true;
    }
    return await _push(prefs, choices, overwrite: false) != null;
  }

  /// [overwrite] faux : si le profil est déjà marqué terminé (préférences
  /// modifiées depuis dans Paramètres), on ne les écrase pas.
  Future<UserPreferences?> _push(
      SharedPreferences prefs, OnboardingChoices choices,
      {required bool overwrite}) async {
    if (_userId == null) {
      return null;
    }
    try {
      final current =
          await remote.fetchPreferences().timeout(kOnboardingTimeout);
      if (!overwrite && current.onboardingCompleted) {
        await prefs.remove(kOnboardingPendingKey);
        return current;
      }
      final saved = await remote
          .savePreferences(choices.applyTo(current))
          .timeout(kOnboardingTimeout);
      await prefs.remove(kOnboardingPendingKey);
      return saved;
    } catch (e) {
      developer.log('profil', name: 'Onboarding', error: e);
      return null;
    }
  }

  /// « Revoir la présentation » : walkthrough et visite guidée proposés à
  /// nouveau sur cet appareil.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kOnboardingDoneKey);
    await prefs.remove(kHomeTourDoneKey);
  }

  /// Visite guidée de la HomePage à lancer : walkthrough terminé et visite
  /// pas encore faite.
  Future<bool> shouldStartHomeTour() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(kOnboardingDoneKey) ?? false) &&
        !(prefs.getBool(kHomeTourDoneKey) ?? false);
  }

  Future<void> markHomeTourDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHomeTourDoneKey, true);
  }
}
