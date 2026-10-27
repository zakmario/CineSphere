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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '/custom_code/actions/cine_local_db.dart';
import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/cine_sync_service.dart';
import '/custom_code/actions/firebase_service.dart';

/// Notifications locales de CinéSphère (cahier des charges, section 6.9).
///
/// Action FlutterFlow d'ancrage, à appeler au chargement de la HomePage :
/// prépare les notifications (sans demander la permission), ouvre la fiche
/// d'une notification qui a lancé l'application et reprogramme les rappels
/// au plus une fois toutes les 6 h. Renvoie vrai si les notifications sont
/// activées dans les réglages.
Future<bool> cineNotificationService() async {
  final service = CineNotificationService.instance;
  await service.init();
  await service.rescheduleIfStale();
  return (await service.loadSettings()).enabled;
}

// Canaux Android -----------------------------------------------------------

enum NotificationChannelKind { releases, episodes, reminders }

/// Canaux Android : chacun peut être coupé dans les réglages du téléphone.
const kNotificationChannels = {
  NotificationChannelKind.releases: AndroidNotificationChannel(
    'cinesphere_releases',
    'Sorties de films',
    description: 'Films de vos favoris ou de vos plateformes qui sortent',
    importance: Importance.high,
  ),
  NotificationChannelKind.episodes: AndroidNotificationChannel(
    'cinesphere_episodes',
    'Nouveaux épisodes',
    description: 'Nouveaux épisodes des séries en favoris',
    importance: Importance.high,
  ),
  NotificationChannelKind.reminders: AndroidNotificationChannel(
    'cinesphere_reminders',
    'Rappels',
    description: 'Rappels demandés avec « Me prévenir »',
    importance: Importance.high,
  ),
};

/// Notifications automatiques programmées au plus (iOS en garde 64).
const int kMaxAutomaticNotifications = 20;

/// Sorties examinées pour les notifications automatiques.
const Duration kAutomaticWindow = Duration(days: 30);

/// Délai minimal entre deux reprogrammations au démarrage.
const Duration kRescheduleInterval = Duration(hours: 6);

/// Nom de la route FlutterFlow de la fiche d'un titre (page du membre 2).
const String kMediaDetailRoute = 'MediaDetail';

// Clés shared_preferences.
const kRemindersKey = 'cs_reminders';
const kReminderDetailsKey = 'cs_reminder_details';
const kAutomaticRemindersKey = 'cs_auto_reminders';
const kNotificationSettingsKey = 'cs_notification_settings';
const kLastRescheduleKey = 'cs_last_reschedule';

/// Clés à effacer à la déconnexion (données du membre).
const kNotificationPrivateKeys = [
  kRemindersKey,
  kReminderDetailsKey,
  kAutomaticRemindersKey,
  kNotificationSettingsKey,
  kLastRescheduleKey,
];

// Fonctions pures --------------------------------------------------------

/// Heure du rappel d'une sortie : la veille ([dayBefore]) ou le jour même à
/// [hour]:[minute], jamais après la sortie. Trop tard : une heure avant la
/// sortie ; sortie passée ou imminente : null.
DateTime? reminderDateFor(
  DateTime releaseAt, {
  required DateTime now,
  int hour = 18,
  int minute = 0,
  bool dayBefore = true,
}) {
  final release = releaseAt.toLocal();
  var remindAt = DateTime(release.year, release.month,
      release.day - (dayBefore ? 1 : 0), hour, minute);
  if (remindAt.isAfter(release)) {
    remindAt = release;
  }
  if (remindAt.isAfter(now)) {
    return remindAt;
  }
  final lastCall = release.subtract(const Duration(hours: 1));
  return lastCall.isAfter(now) ? lastCall : null;
}

/// Charge utile d'une notification : type et identifiant TMDB du titre
/// (fiche à ouvrir), identifiant de la notification Firestore.
String notificationPayload(
        {required String mediaType, required int tmdbId, String? id}) =>
    jsonEncode({
      'type': mediaType,
      'tmdbId': tmdbId,
      if (id != null) 'id': id,
    });

/// Inverse de [notificationPayload] ; null si illisible.
({String mediaKey, String? id})? parseNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) {
    return null;
  }
  try {
    final data = jsonDecode(payload);
    if (data is! Map) {
      return null;
    }
    final type = data['type'];
    final tmdbId = data['tmdbId'];
    if ((type != 'movie' && type != 'series') || tmdbId is! num) {
      return null;
    }
    return (
      mediaKey: mediaKey(type as String, tmdbId.toInt()),
      id: data['id'] as String?,
    );
  } catch (_) {
    return null;
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String notificationTimeLabel(DateTime date) =>
    '${_two(date.hour)}:${_two(date.minute)}';

// Réglages ---------------------------------------------------------------

/// Réglages des notifications : `users/{uid}.preferences` (activées,
/// sorties, séries favorites, heure, plateformes suivies) et, sur l'appareil
/// seulement, le choix « la veille / le jour J ».
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.releases = true,
    this.favoriteSeries = true,
    this.time = const TimeOfDay(hour: 18, minute: 0),
    this.dayBefore = true,
    this.platforms = const [],
  });

  final bool enabled;

  /// Sorties de films (favoris ou plateformes suivies).
  final bool releases;

  /// Nouveaux épisodes des séries en favoris.
  final bool favoriteSeries;
  final TimeOfDay time;

  /// Rappel la veille (sinon le jour de la sortie).
  final bool dayBefore;

  /// Plateformes suivies (noms, comme `releaseEvents.platform`).
  final List<String> platforms;

  factory NotificationSettings.fromPreferences(UserPreferences prefs,
          {bool dayBefore = true}) =>
      NotificationSettings(
        enabled: prefs.notificationsEnabled,
        releases: prefs.notifyReleases,
        favoriteSeries: prefs.notifyFavoriteSeries,
        time: prefs.reminderTime,
        dayBefore: dayBefore,
        platforms: prefs.favoritePlatforms,
      );

  UserPreferences applyTo(UserPreferences prefs) => prefs.copyWith(
        notificationsEnabled: enabled,
        notifyReleases: releases,
        notifyFavoriteSeries: favoriteSeries,
        reminderTime: time,
        favoritePlatforms: platforms,
      );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        enabled: json['enabled'] as bool? ?? true,
        releases: json['releases'] as bool? ?? true,
        favoriteSeries: json['favorite_series'] as bool? ?? true,
        time: parseTimeOfDay(json['time'] as String?),
        dayBefore: json['day_before'] as bool? ?? true,
        platforms: (json['platforms'] as List?)?.whereType<String>().toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'releases': releases,
        'favorite_series': favoriteSeries,
        'time': formatTimeOfDay(time),
        'day_before': dayBefore,
        'platforms': platforms,
      };

  NotificationSettings copyWith({
    bool? enabled,
    bool? releases,
    bool? favoriteSeries,
    TimeOfDay? time,
    bool? dayBefore,
    List<String>? platforms,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        releases: releases ?? this.releases,
        favoriteSeries: favoriteSeries ?? this.favoriteSeries,
        time: time ?? this.time,
        dayBefore: dayBefore ?? this.dayBefore,
        platforms: platforms ?? this.platforms,
      );

  DateTime? reminderFor(DateTime releaseAt, DateTime now) => reminderDateFor(
        releaseAt,
        now: now,
        hour: time.hour,
        minute: time.minute,
        dayBefore: dayBefore,
      );
}

// Rappels ----------------------------------------------------------------

/// Rappel d'une sortie : demandé (« Me prévenir ») ou automatique.
class ReleaseReminder {
  const ReleaseReminder({
    required this.key,
    required this.eventId,
    required this.mediaType,
    required this.tmdbId,
    required this.title,
    required this.releaseAt,
    this.platform,
    this.seasonNumber,
    this.episodeNumber,
    this.automatic = false,
  });

  /// Identifiant du rappel et de sa notification Firestore : l'id de la
  /// sortie, préfixé de `auto_` pour un rappel automatique.
  final String key;
  final String eventId;
  final String mediaType;
  final int tmdbId;
  final String title;
  final DateTime releaseAt;
  final String? platform;
  final int? seasonNumber;
  final int? episodeNumber;
  final bool automatic;

  String get mediaKeyValue => mediaKey(mediaType, tmdbId);
  bool get isEpisode => mediaType == 'series';

  NotificationChannelKind get channel => !automatic
      ? NotificationChannelKind.reminders
      : isEpisode
          ? NotificationChannelKind.episodes
          : NotificationChannelKind.releases;

  /// Une sortie ([releaseEventRow]) -> rappel ; null si incomplète.
  static ReleaseReminder? fromEvent(Map<String, dynamic> event,
      {bool automatic = false}) {
    final id = event['id'] as String?;
    final type = event['media_type'] as String?;
    final tmdbId = (event['tmdb_id'] as num?)?.toInt();
    final releaseAt = releaseDateOf(event);
    if (id == null || type == null || tmdbId == null || releaseAt == null) {
      return null;
    }
    return ReleaseReminder(
      key: automatic ? 'auto_$id' : id,
      eventId: id,
      mediaType: type,
      tmdbId: tmdbId,
      title: event['title'] as String? ?? 'Nouvelle sortie',
      releaseAt: releaseAt,
      platform: event['platform'] as String?,
      seasonNumber: (event['season_number'] as num?)?.toInt(),
      episodeNumber: (event['episode_number'] as num?)?.toInt(),
      automatic: automatic,
    );
  }

  String get episodeText {
    final parts = [
      if ((seasonNumber ?? 0) > 0) 'S$seasonNumber',
      if ((episodeNumber ?? 0) > 0) 'É$episodeNumber',
    ];
    return parts.isEmpty ? 'Nouvel épisode' : 'Épisode ${parts.join(' · ')}';
  }

  /// Texte de la notification.
  String get body {
    final local = releaseAt.toLocal();
    final where = platform == null || platform!.isEmpty ? '' : ' sur $platform';
    return '${isEpisode ? episodeText : 'Sortie'} le '
        '${formatReleaseDate(local)} à ${notificationTimeLabel(local)}$where';
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'event_id': eventId,
        'media_type': mediaType,
        'tmdb_id': tmdbId,
        'title': title,
        'release_at': releaseAt.toUtc().toIso8601String(),
        'platform': platform,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        'automatic': automatic,
      };

  factory ReleaseReminder.fromJson(Map<String, dynamic> json) =>
      ReleaseReminder(
        key: json['key'] as String,
        eventId: json['event_id'] as String,
        mediaType: json['media_type'] as String,
        tmdbId: (json['tmdb_id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        releaseAt: DateTime.parse(json['release_at'] as String),
        platform: json['platform'] as String?,
        seasonNumber: (json['season_number'] as num?)?.toInt(),
        episodeNumber: (json['episode_number'] as num?)?.toInt(),
        automatic: json['automatic'] as bool? ?? false,
      );
}

/// Résultat de [CineNotificationService.scheduleReminder].
class ReminderResult {
  const ReminderResult.scheduled(DateTime this.at) : error = null;
  const ReminderResult.failed(String this.error) : at = null;

  final DateTime? at;
  final String? error;

  bool get ok => at != null;
}

// Notifications Firestore (users/{uid}/notifications) ------------------------

class NotificationEntry {
  const NotificationEntry({
    required this.id,
    required this.title,
    required this.message,
    this.mediaType,
    this.tmdbId,
    this.releaseEventId,
    this.scheduledAt,
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String? mediaType;
  final int? tmdbId;
  final String? releaseEventId;
  final DateTime? scheduledAt;
  final bool isRead;
  final DateTime? createdAt;

  /// Clé `movie_550` du titre lié, null si aucun.
  String? get mediaKeyValue =>
      (mediaType == 'movie' || mediaType == 'series') && tmdbId != null
          ? mediaKey(mediaType!, tmdbId!)
          : null;

  /// Date affichée : la remise prévue, sinon la création.
  DateTime? get date => scheduledAt ?? createdAt;

  bool isDue(DateTime now) => scheduledAt == null || !scheduledAt!.isAfter(now);

  /// Ligne [cineRow] -> entrée.
  factory NotificationEntry.fromRow(Map<String, dynamic> row) =>
      NotificationEntry(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        message: row['message'] as String? ?? '',
        mediaType: row['media_type'] as String?,
        tmdbId: (row['tmdb_id'] as num?)?.toInt(),
        releaseEventId: row['release_event_id'] as String?,
        scheduledAt: DateTime.tryParse('${row['scheduled_at'] ?? ''}'),
        isRead: row['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
      );

  /// Champs écrits (snake_case, voir toFirestoreFields).
  Map<String, dynamic> toPayload() => {
        'title': title,
        'message': message,
        'media_type': mediaType,
        'tmdb_id': tmdbId,
        'release_event_id': releaseEventId,
        'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'is_read': isRead,
        'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  NotificationEntry copyWith({bool? isRead}) => NotificationEntry(
        id: id,
        title: title,
        message: message,
        mediaType: mediaType,
        tmdbId: tmdbId,
        releaseEventId: releaseEventId,
        scheduledAt: scheduledAt,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

/// Une page de notifications ; [cursor] se passe à l'appel suivant.
class NotificationPage {
  const NotificationPage(
      {required this.items, this.cursor, this.hasMore = false});

  final List<NotificationEntry> items;
  final Object? cursor;
  final bool hasMore;
}

/// Accès à `users/{uid}/notifications` (remplacé dans les tests). Les
/// écritures passent par [CineSyncService.write] : hors connexion, elles
/// attendent dans pending_sync.
class NotificationStore {
  NotificationStore({CineFirebaseService? remote, CineSyncService? sync})
      : _remote = remote,
        _sync = sync;

  final CineFirebaseService? _remote;
  final CineSyncService? _sync;

  CineFirebaseService get remote => _remote ?? CineFirebaseService.instance;
  CineSyncService get sync => _sync ?? CineSyncService.instance;

  String? get userId => remote.currentUserId;

  /// Notifications déjà remises (scheduledAt ≤ [now]), les plus récentes
  /// d'abord. Un seul champ dans la requête : pas d'index composite.
  Future<NotificationPage> fetchPage(
          {Object? after, int pageSize = kPageSize, required DateTime now}) =>
      remote.guard('fetchNotifications', () async {
        var query = remote
            .mine('notifications')
            .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
            .orderBy('scheduledAt', descending: true)
            .limit(pageSize);
        if (after is DocumentSnapshot) {
          query = query.startAfterDocument(after);
        }
        final snap = await query.get();
        return NotificationPage(
          items: [
            for (final d in snap.docs) NotificationEntry.fromRow(cineRow(d))
          ],
          cursor: snap.docs.isEmpty ? after : snap.docs.last,
          hasMore: snap.docs.length == pageSize,
        );
      });

  /// Notifications non lues (remises ou à venir), en temps réel.
  Stream<List<NotificationEntry>> watchUnread() {
    if (userId == null) {
      return Stream.value(const []);
    }
    return remote
        .mine('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) =>
            [for (final d in snap.docs) NotificationEntry.fromRow(cineRow(d))]);
  }

  Future<void> _write(SyncOperation operation, String id,
      [Map<String, dynamic> payload = const {}]) async {
    final uid = userId;
    if (uid == null) {
      return;
    }
    await sync.write(PendingSyncOperation(
      userId: uid,
      operation: operation,
      collection: 'users/$uid/notifications',
      docId: id,
      payload: payload,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> save(NotificationEntry entry) =>
      _write(SyncOperation.set, entry.id, entry.toPayload());

  Future<void> delete(String id) => _write(SyncOperation.delete, id);

  Future<void> markRead(String id) =>
      _write(SyncOperation.update, id, {'is_read': true});

  /// Marque toutes les notifications remises comme lues ; renvoie leur
  /// nombre.
  Future<int> markAllRead({required DateTime now}) async {
    final unread = await watchUnread().first;
    final due = unread.where((n) => n.isDue(now)).toList();
    for (final entry in due) {
      await markRead(entry.id);
    }
    return due.length;
  }
}

// Plugin -------------------------------------------------------------------

/// Notifications du système (remplacé dans les tests).
abstract class LocalNotifier {
  /// [onTap] reçoit la charge utile d'une notification touchée.
  Future<bool> initialize(void Function(String? payload) onTap);

  Future<bool> requestPermission();

  /// Charge utile de la notification qui a lancé l'application.
  Future<String?> launchPayload();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationChannelKind channel,
    String? payload,
  });

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationChannelKind channel,
    String? payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

/// flutter_local_notifications : canaux Android, fuseau horaire de
/// l'appareil (flutter_timezone), rappels en mode inexact (pas besoin de la
/// permission « alarmes exactes »). Sur le web, le navigateur ne programme
/// rien : un Timer affiche le rappel tant que l'onglet reste ouvert.
class FlutterLocalNotifier implements LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _webTimers = <int, Timer>{};
  bool _ready = false;

  @override
  Future<bool> initialize(void Function(String? payload) onTap) async {
    if (_ready) {
      return true;
    }
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (e) {
      // Fuseau inconnu : les dates sont converties depuis l'UTC.
      debugPrint('fuseau horaire : $e');
    }
    final ok = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    _ready = ok ?? false;
    final android = _android;
    if (_ready && android != null) {
      for (final channel in kNotificationChannels.values) {
        await android.createNotificationChannel(channel);
      }
    }
    return _ready;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          : null;

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  WebFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<String?> launchPayload() async {
    if (kIsWeb) {
      return null;
    }
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  NotificationDetails _details(NotificationChannelKind kind) {
    final channel = kNotificationChannels[kind]!;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationChannelKind channel,
    String? payload,
  }) async {
    if (kIsWeb) {
      _webTimers.remove(id)?.cancel();
      _webTimers[id] = Timer(at.difference(DateTime.now()), () {
        _webTimers.remove(id);
        show(
            id: id,
            title: title,
            body: body,
            channel: channel,
            payload: payload);
      });
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: _details(channel),
    );
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationChannelKind channel,
    String? payload,
  }) =>
      _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: _details(channel),
      );

  @override
  Future<void> cancel(int id) async {
    _webTimers.remove(id)?.cancel();
    if (!kIsWeb) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> cancelAll() async {
    for (final timer in _webTimers.values) {
      timer.cancel();
    }
    _webTimers.clear();
    if (!kIsWeb) {
      await _plugin.cancelAll();
    }
  }
}

// Service ---------------------------------------------------------------

/// Programmation des rappels et réglages (section 6.9).
///
/// - Rappels « Me prévenir » (canal reminders) : gardés sur l'appareil
///   (`cs_reminders` + détails) pour être reprogrammés si l'heure change ;
/// - notifications automatiques des 30 prochains jours (canaux releases et
///   episodes) : séries favorites, films favoris ou des plateformes suivies ;
/// - chaque notification programmée est notée dans
///   `users/{uid}/notifications` (page Notifications, badge) ;
/// - toucher une notification ouvre la fiche du titre (MediaDetail).
class CineNotificationService {
  CineNotificationService({
    LocalNotifier? notifier,
    NotificationStore? store,
    CineLocalDb? local,
    CineFirebaseService? remote,
    DateTime Function() now = DateTime.now,
    void Function(String mediaKey)? openMedia,
  })  : _notifier = notifier,
        _store = store,
        _local = local,
        _remote = remote,
        _now = now,
        _openMedia = openMedia;

  static CineNotificationService? _instance;
  static CineNotificationService? _override;

  static CineNotificationService get instance =>
      _override ?? (_instance ??= CineNotificationService());

  @visibleForTesting
  static set debugInstance(CineNotificationService? service) =>
      _override = service;

  LocalNotifier? _notifier;
  NotificationStore? _store;
  final CineLocalDb? _local;
  final CineFirebaseService? _remote;
  final DateTime Function() _now;
  final void Function(String mediaKey)? _openMedia;

  LocalNotifier get notifier => _notifier ??= FlutterLocalNotifier();
  NotificationStore get store => _store ??= NotificationStore();
  CineLocalDb get local => _local ?? CineLocalDb.instance;
  CineFirebaseService get remote => _remote ?? CineFirebaseService.instance;
  DateTime now() => _now();

  final _taps = StreamController<String>.broadcast();

  /// Titres (`movie_550`) ouverts depuis une notification.
  Stream<String> get taps => _taps.stream;

  Future<bool>? _initializing;

  /// Prépare le plugin une seule fois (et ouvre la fiche si une
  /// notification a lancé l'application). [requestPermission] : demande
  /// l'autorisation d'afficher des notifications.
  Future<bool> init({bool requestPermission = false}) async {
    try {
      final ready = await (_initializing ??= _init());
      if (!ready || !requestPermission) {
        return ready;
      }
      return await notifier.requestPermission();
    } catch (e) {
      debugPrint('notifications : $e');
      return false;
    }
  }

  Future<bool> _init() async {
    final ready = await notifier.initialize(handleTap);
    if (ready) {
      final payload = await notifier.launchPayload();
      if (payload != null) {
        await handleTap(payload);
      }
    }
    return ready;
  }

  // Réglages ------------------------------------------------------------

  Future<NotificationSettings> _mirror(SharedPreferences prefs) async {
    final text = prefs.getString(kNotificationSettingsKey);
    if (text == null) {
      return const NotificationSettings();
    }
    try {
      return NotificationSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(text) as Map));
    } catch (_) {
      return const NotificationSettings();
    }
  }

  /// Réglages du membre : profil Firestore (copie gardée sur l'appareil
  /// pour fonctionner hors connexion) + « la veille / le jour J ».
  Future<NotificationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final mirror = await _mirror(prefs);
    if (remote.currentUserId == null) {
      return mirror;
    }
    try {
      final saved =
          await remote.fetchPreferences().timeout(const Duration(seconds: 5));
      final settings = NotificationSettings.fromPreferences(saved,
          dayBefore: mirror.dayBefore);
      await prefs.setString(
          kNotificationSettingsKey, jsonEncode(settings.toJson()));
      return settings;
    } catch (e) {
      return mirror;
    }
  }

  /// Enregistre les réglages (appareil tout de suite, profil Firestore en
  /// arrière-plan) puis reprogramme les notifications.
  Future<int> saveSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        kNotificationSettingsKey, jsonEncode(settings.toJson()));
    if (remote.currentUserId != null) {
      // Hors connexion, Firestore garde l'écriture : on ne l'attend pas.
      unawaited(() async {
        try {
          final current = await remote.fetchPreferences();
          await remote.savePreferences(settings.applyTo(current));
        } catch (e) {
          developer.log('saveSettings', name: 'Notifications', error: e);
        }
      }());
    }
    return rescheduleAll(settings: settings);
  }

  // Registre des rappels ------------------------------------------------

  Future<Map<String, ReleaseReminder>> _details(SharedPreferences prefs) async {
    final text = prefs.getString(kReminderDetailsKey);
    if (text == null) {
      return {};
    }
    try {
      final map = jsonDecode(text) as Map;
      return {
        for (final e in map.entries)
          '${e.key}': ReleaseReminder.fromJson(
              Map<String, dynamic>.from(e.value as Map)),
      };
    } catch (_) {
      return {};
    }
  }

  /// Enregistre les rappels [after] (remplaçant [before]). `cs_reminders`
  /// (lu par les cloches des widgets) garde aussi les rappels programmés
  /// sans détails par l'ancienne action scheduleReleaseNotification.
  Future<void> _saveDetails(
      SharedPreferences prefs,
      Map<String, ReleaseReminder> before,
      Map<String, ReleaseReminder> after) async {
    final legacy = (prefs.getStringList(kRemindersKey) ?? const <String>[])
        .where((k) => !before.containsKey(k));
    await prefs.setString(kReminderDetailsKey,
        jsonEncode({for (final e in after.entries) e.key: e.value.toJson()}));
    await prefs.setStringList(
        kRemindersKey, {...legacy, ...after.keys}.toList());
  }

  /// Rappels « Me prévenir » enregistrés.
  Future<List<ReleaseReminder>> reminders() async =>
      (await _details(await SharedPreferences.getInstance())).values.toList();

  // Programmation -------------------------------------------------------

  Future<bool> _schedule(ReleaseReminder reminder, DateTime at) async {
    try {
      await notifier.schedule(
        id: notificationIdFromString(reminder.key),
        title: reminder.title,
        body: reminder.body,
        at: at,
        channel: reminder.channel,
        payload: notificationPayload(
            mediaType: reminder.mediaType,
            tmdbId: reminder.tmdbId,
            id: reminder.key),
      );
      return true;
    } catch (e) {
      debugPrint('programmation ${reminder.key} : $e');
      return false;
    }
  }

  Future<void> _record(ReleaseReminder reminder, DateTime at) async {
    try {
      await store.save(NotificationEntry(
        id: reminder.key,
        title: reminder.title,
        message: reminder.body,
        mediaType: reminder.mediaType,
        tmdbId: reminder.tmdbId,
        releaseEventId: reminder.eventId,
        scheduledAt: at,
        createdAt: now(),
      ));
    } catch (e) {
      developer.log('notification Firestore', name: 'Notifications', error: e);
    }
  }

  /// « Me prévenir » : programme le rappel à l'heure choisie dans les
  /// réglages et le garde pour le reprogrammer si l'heure change.
  Future<ReminderResult> scheduleReminder(ReleaseReminder reminder) async {
    final settings = await loadSettings();
    if (!settings.enabled) {
      return const ReminderResult.failed(
          'Notifications désactivées dans les paramètres.');
    }
    final at = settings.reminderFor(reminder.releaseAt, now());
    if (at == null) {
      return const ReminderResult.failed(
          'Trop tard pour un rappel : la sortie est imminente.');
    }
    if (!await init(requestPermission: true) ||
        !await _schedule(reminder, at)) {
      return const ReminderResult.failed(
          'Impossible de programmer le rappel (notifications refusées ?)');
    }
    final prefs = await SharedPreferences.getInstance();
    final details = await _details(prefs);
    await _saveDetails(prefs, details, {...details, reminder.key: reminder});
    await _record(reminder, at);
    return ReminderResult.scheduled(at);
  }

  /// Annule un rappel (et sa notification Firestore si elle n'est pas
  /// encore remise).
  Future<void> cancelReminder(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final details = await _details(prefs);
    final removed = details[key];
    await _saveDetails(prefs, details, Map.of(details)..remove(key));
    await prefs.setStringList(
        kRemindersKey,
        (prefs.getStringList(kRemindersKey) ?? [])
            .where((k) => k != key)
            .toList());
    try {
      await notifier.cancel(notificationIdFromString(key));
    } catch (e) {
      debugPrint('annulation $key : $e');
    }
    if (removed != null) {
      try {
        await store.delete(key);
      } catch (e) {
        developer.log('suppression $key', name: 'Notifications', error: e);
      }
    }
  }

  /// Annule toutes les notifications programmées (les rappels restent
  /// enregistrés : ils reviennent si les notifications sont réactivées).
  Future<void> cancelAll() async {
    try {
      await notifier.cancelAll();
    } catch (e) {
      debugPrint('cancelAll : $e');
    }
  }

  /// Reprogramme tout avec les réglages actuels : rappels « Me prévenir »
  /// (les sorties passées sont oubliées) et notifications automatiques.
  /// Renvoie le nombre de notifications programmées.
  Future<int> rescheduleAll({NotificationSettings? settings}) async {
    final current = settings ?? await loadSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLastRescheduleKey, now().toIso8601String());
    final details = await _details(prefs);
    final previousAuto = prefs.getStringList(kAutomaticRemindersKey) ?? [];

    for (final key in [...details.keys, ...previousAuto]) {
      try {
        await notifier.cancel(notificationIdFromString(key));
      } catch (_) {}
    }
    if (!current.enabled) {
      await cancelAll();
      await prefs.setStringList(kAutomaticRemindersKey, const []);
      return 0;
    }
    if (!await init()) {
      return 0;
    }

    var count = 0;
    final kept = <String, ReleaseReminder>{};
    for (final reminder in details.values) {
      if (!reminder.releaseAt.isAfter(now())) {
        continue;
      }
      kept[reminder.key] = reminder;
      final at = current.reminderFor(reminder.releaseAt, now());
      if (at != null && await _schedule(reminder, at)) {
        count++;
      }
    }
    await _saveDetails(prefs, details, kept);

    final automatic = await _automaticReminders(current, kept);
    final autoKeys = <String>[];
    for (final reminder in automatic) {
      final at = current.reminderFor(reminder.releaseAt, now());
      if (at == null || !await _schedule(reminder, at)) {
        continue;
      }
      count++;
      autoKeys.add(reminder.key);
      if (!previousAuto.contains(reminder.key)) {
        await _record(reminder, at);
      }
    }
    await prefs.setStringList(kAutomaticRemindersKey, autoKeys);
    return count;
  }

  /// [rescheduleAll] si la dernière date de plus de [kRescheduleInterval].
  Future<void> rescheduleIfStale() async {
    final prefs = await SharedPreferences.getInstance();
    final last = DateTime.tryParse(prefs.getString(kLastRescheduleKey) ?? '');
    if (last == null || now().difference(last) >= kRescheduleInterval) {
      await rescheduleAll();
    }
  }

  /// Sorties des 30 prochains jours à annoncer : épisodes des séries
  /// favorites ([NotificationSettings.favoriteSeries]) ; films favoris ou
  /// des plateformes suivies ([NotificationSettings.releases]).
  Future<List<ReleaseReminder>> _automaticReminders(
      NotificationSettings settings,
      Map<String, ReleaseReminder> manual) async {
    final userId = remote.currentUserId;
    if (userId == null || (!settings.releases && !settings.favoriteSeries)) {
      return const [];
    }
    final start = now();
    List<Map<String, dynamic>> events;
    Set<String> favorites;
    try {
      events =
          (await local.watchCalendar(start, start.add(kAutomaticWindow)).last)
              .data;
      favorites = local.isSupported
          ? {
              for (final f in await local.localFavorites(userId))
                f['id'] as String
            }
          : {for (final d in (await remote.mine('favorites').get()).docs) d.id};
    } catch (e) {
      developer.log('automatiques', name: 'Notifications', error: e);
      return const [];
    }
    final manualEvents = {for (final r in manual.values) r.eventId};
    final reminders = <ReleaseReminder>[];
    for (final event in events) {
      final reminder = ReleaseReminder.fromEvent(event, automatic: true);
      if (reminder == null ||
          manualEvents.contains(reminder.eventId) ||
          !reminder.releaseAt.isAfter(start)) {
        continue;
      }
      final favorite = favorites.contains(reminder.mediaKeyValue);
      final wanted = reminder.isEpisode
          ? settings.favoriteSeries && favorite
          : settings.releases &&
              (favorite || settings.platforms.contains(reminder.platform));
      if (wanted) {
        reminders.add(reminder);
      }
    }
    reminders.sort((a, b) => a.releaseAt.compareTo(b.releaseAt));
    return reminders.take(kMaxAutomaticNotifications).toList();
  }

  /// Notification immédiate (bouton « Tester »).
  Future<bool> showNow(String title, String body) async {
    if (!await init(requestPermission: true)) {
      return false;
    }
    try {
      await notifier.show(
        id: now().millisecondsSinceEpoch & 0x7FFFFFFF,
        title: title,
        body: body,
        channel: NotificationChannelKind.reminders,
      );
      return true;
    } catch (e) {
      debugPrint('showNow : $e');
      return false;
    }
  }

  // Tap sur une notification ---------------------------------------------

  /// Marque la notification comme lue et ouvre la fiche du titre.
  Future<void> handleTap(String? payload) async {
    final parsed = parseNotificationPayload(payload);
    if (parsed == null) {
      return;
    }
    final id = parsed.id;
    if (id != null) {
      unawaited(store.markRead(id).catchError((Object e) =>
          developer.log('markRead', name: 'Notifications', error: e)));
    }
    _taps.add(parsed.mediaKey);
    (_openMedia ?? _navigateToMedia)(parsed.mediaKey);
  }

  /// Ouvre MediaDetail par le navigateur de FlutterFlow (appNavigatorKey).
  /// Au lancement, attend que la première page soit affichée.
  static void _navigateToMedia(String key) {
    Future<void> attempt(int remaining) async {
      final context = appNavigatorKey.currentContext;
      if (context == null) {
        if (remaining > 0) {
          await Future.delayed(const Duration(milliseconds: 300));
          return attempt(remaining - 1);
        }
        return;
      }
      try {
        GoRouter.of(context)
            .pushNamed(kMediaDetailRoute, queryParameters: {'mediaId': key});
      } catch (e) {
        debugPrint('ouverture de $key : $e');
      }
    }

    attempt(20);
  }
}
