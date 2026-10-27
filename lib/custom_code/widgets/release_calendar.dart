// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shimmer/shimmer.dart';
import 'package:table_calendar/table_calendar.dart';

import '/custom_code/actions/cine_local_db.dart';
import '/custom_code/actions/cine_notification_service.dart';
import '/custom_code/actions/cine_sync_service.dart';
import '/custom_code/actions/firebase_service.dart';

/// Calendrier des sorties (cahier des charges, section 6.8) : vue mois ou
/// semaine (table_calendar), points colorés par jour (or = film, violet =
/// épisode), liste des sorties du jour choisi, filtres par plateforme et
/// « Mes favoris », bouton « Me prévenir ». Les sorties viennent de SQLite
/// puis de Firestore (`releaseEvents`) : le calendrier reste consultable hors
/// connexion pour les mois déjà ouverts.
class ReleaseCalendar extends StatefulWidget {
  const ReleaseCalendar({
    super.key,
    this.width,
    this.height,
    this.initialView,
    this.onItemTap,
  });

  final double? width;
  final double? height;

  /// `month` (par défaut) ou `week`.
  final String? initialView;
  final Future Function(String selectedMediaId)? onItemTap;

  @override
  State<ReleaseCalendar> createState() => _ReleaseCalendarState();
}

// Fonctions pures (testées) ---------------------------------------------------

/// Période chargée pour le mois de [focusedDay] : le mois entier plus
/// 7 jours de chaque côté (jours des mois voisins affichés dans la grille).
({DateTime from, DateTime to}) calendarRangeFor(DateTime focusedDay) {
  final day = focusedDay.toLocal();
  return (
    from: DateTime(day.year, day.month, 1).subtract(const Duration(days: 7)),
    to: DateTime(day.year, day.month + 1, 1).add(const Duration(days: 7)),
  );
}

/// Jour (minuit UTC, comme table_calendar) d'une sortie, à l'heure locale.
DateTime calendarDayOf(Map<String, dynamic> event) {
  final date = releaseDateOf(event)!.toLocal();
  return DateTime.utc(date.year, date.month, date.day);
}

bool isEpisodeEvent(Map<String, dynamic> event) =>
    event['media_type'] == 'series';

/// Sorties gardées par les filtres : plateformes choisies (toutes si vide)
/// et, si [favoritesOnly], titres de [favoriteKeys] seulement.
List<Map<String, dynamic>> filterReleaseEvents(
  Iterable<Map<String, dynamic>> events, {
  Set<String> platforms = const {},
  bool favoritesOnly = false,
  Set<String> favoriteKeys = const {},
}) =>
    events
        .where((e) =>
            releaseDateOf(e) != null &&
            (platforms.isEmpty || platforms.contains(e['platform'])) &&
            (!favoritesOnly || favoriteKeys.contains(e['media_key'])))
        .toList();

/// Sorties regroupées par jour ([calendarDayOf]), dans l'ordre de l'heure.
Map<DateTime, List<Map<String, dynamic>>> groupReleaseEventsByDay(
    Iterable<Map<String, dynamic>> events) {
  final days = <DateTime, List<Map<String, dynamic>>>{};
  for (final event in events) {
    days.putIfAbsent(calendarDayOf(event), () => []).add(event);
  }
  for (final list in days.values) {
    list.sort((a, b) => releaseDateOf(a)!.compareTo(releaseDateOf(b)!));
  }
  return days;
}

String _time(DateTime date) => notificationTimeLabel(date);

/// « S2 · É5 » pour un épisode, « Série » sinon.
String episodeLabel(Map<String, dynamic> event) {
  final season = (event['season_number'] as num?)?.toInt() ?? 0;
  final episode = (event['episode_number'] as num?)?.toInt() ?? 0;
  if (season <= 0 && episode <= 0) {
    return 'Série';
  }
  return [
    if (season > 0) 'S$season',
    if (episode > 0) 'É$episode',
  ].join(' · ');
}

// Widget -----------------------------------------------------------------

class _ReleaseCalendarState extends State<ReleaseCalendar> {
  final _subscriptions = <StreamSubscription>[];
  StreamSubscription<CacheResult<List<Map<String, dynamic>>>>? _loading;

  bool _localeReady = false;
  late CalendarFormat _format;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  ({DateTime from, DateTime to})? _range;

  List<Map<String, dynamic>> _events = const [];
  Map<DateTime, List<Map<String, dynamic>>> _byDay = const {};
  bool _busy = true;
  String? _error;
  CacheResult<List<Map<String, dynamic>>>? _result;

  final Set<String> _platforms = {};
  bool _favoritesOnly = false;
  Set<String> _favoriteKeys = {};
  Set<String> _reminders = {};

  CineLocalDb get _local => CineLocalDb.instance;

  @override
  void initState() {
    super.initState();
    _format = widget.initialView == 'week'
        ? CalendarFormat.week
        : CalendarFormat.month;
    final now = _local.now().toLocal();
    _focusedDay = DateTime.utc(now.year, now.month, now.day);
    _selectedDay = _focusedDay;

    _subscriptions
      ..add(CineFirebaseService.instance.mediaChanges.listen((change) {
        if (change.flag == MediaFlag.favorite && mounted) {
          setState(() {
            change.value
                ? _favoriteKeys.add(change.mediaId)
                : _favoriteKeys.remove(change.mediaId);
            _applyFilters();
          });
        }
      }))
      ..add(CineSyncService.instance.events.listen((event) {
        if (event.kind == SyncEventKind.synced) {
          _loadFavorites();
        }
      }));

    initializeDateFormatting('fr_FR').then((_) {
      if (mounted) {
        setState(() => _localeReady = true);
      }
    });
    _loadReminders();
    _loadFavorites();
    _load();
  }

  @override
  void dispose() {
    _loading?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  // Données ------------------------------------------------------------

  void _load({bool force = false}) {
    final range = calendarRangeFor(_focusedDay);
    _range = range;
    _loading?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    _loading =
        _local.watchCalendar(range.from, range.to, forceRefresh: force).listen(
      (result) {
        if (!mounted || _range != range) {
          return;
        }
        setState(() {
          _result = result;
          _events = result.data;
          _applyFilters();
        });
      },
      onError: (Object error) {
        if (mounted && _range == range) {
          setState(() {
            _error =
                error is CineFailure && error.kind == CineFailureKind.network
                    ? 'Hors connexion : ce mois n\'a pas encore été enregistré.'
                    : 'Impossible de charger le calendrier.';
          });
        }
      },
      onDone: () {
        if (mounted && _range == range) {
          setState(() => _busy = false);
        }
      },
    );
  }

  Future<void> _loadFavorites() async {
    final userId = CineFirebaseService.instance.currentUserId;
    if (userId == null) {
      return;
    }
    Set<String> keys;
    try {
      if (_local.isSupported) {
        keys = {
          for (final f in await _local.localFavorites(userId)) f['id'] as String
        };
      } else {
        // Web : pas de copie SQLite, on lit les favoris Firestore.
        final snap = await CineFirebaseService.instance.mine('favorites').get();
        keys = {for (final doc in snap.docs) doc.id};
      }
    } catch (e) {
      debugPrint('ReleaseCalendar favoris : $e');
      return;
    }
    if (mounted) {
      setState(() {
        _favoriteKeys = keys;
        _applyFilters();
      });
    }
  }

  Future<void> _loadReminders() async {
    final keys = await getScheduledReminders();
    if (mounted) {
      setState(() => _reminders = keys.toSet());
    }
  }

  void _applyFilters() {
    _byDay = groupReleaseEventsByDay(filterReleaseEvents(
      _events,
      platforms: _platforms,
      favoritesOnly: _favoritesOnly,
      favoriteKeys: _favoriteKeys,
    ));
  }

  List<Map<String, dynamic>> _eventsOf(DateTime day) =>
      _byDay[DateTime.utc(day.year, day.month, day.day)] ?? const [];

  List<String> get _availablePlatforms => {
        for (final e in _events)
          if (e['platform'] is String && (e['platform'] as String).isNotEmpty)
            e['platform'] as String,
      }.toList()
        ..sort();

  // Rappels ------------------------------------------------------------

  Future<void> _toggleReminder(Map<String, dynamic> event) async {
    final key = event['id'] as String;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final notifications = CineNotificationService.instance;
    if (_reminders.contains(key)) {
      await notifications.cancelReminder(key);
      if (!mounted) {
        return;
      }
      setState(() => _reminders.remove(key));
      messenger.showSnackBar(const SnackBar(content: Text('Rappel supprimé')));
      return;
    }

    final reminder = ReleaseReminder.fromEvent(event);
    if (reminder == null) {
      return;
    }
    // Heure et jour (veille / jour J) choisis dans les réglages.
    final result = await notifications.scheduleReminder(reminder);
    if (!mounted) {
      return;
    }
    final at = result.at;
    if (at != null) {
      setState(() => _reminders.add(key));
    }
    messenger.showSnackBar(SnackBar(
      content: Text(at != null
          ? 'Rappel le ${formatReleaseDate(at)} à ${_time(at)}'
          : result.error!),
    ));
  }

  // Affichage ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          _buildFilters(theme),
          if (_localeReady) _buildCalendar(theme) else _calendarShimmer(theme),
          _buildStatus(theme),
          Expanded(child: _buildDayList(theme)),
        ],
      ),
    );
  }

  Widget _buildFilters(FlutterFlowTheme theme) {
    Widget chip(String label, bool selected, ValueChanged<bool> onSelected,
            {IconData? icon}) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(label),
            avatar: icon == null ? null : Icon(icon, size: 18),
            selected: selected,
            onSelected: onSelected,
            selectedColor: theme.primary.withValues(alpha: 0.25),
          ),
        );

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          chip('Mes favoris', _favoritesOnly, icon: Icons.favorite_rounded,
              (value) {
            setState(() {
              _favoritesOnly = value;
              _applyFilters();
            });
          }),
          for (final platform in _availablePlatforms)
            chip(platform, _platforms.contains(platform), (value) {
              setState(() {
                value ? _platforms.add(platform) : _platforms.remove(platform);
                _applyFilters();
              });
            }),
        ],
      ),
    );
  }

  Widget _buildCalendar(FlutterFlowTheme theme) =>
      TableCalendar<Map<String, dynamic>>(
        locale: 'fr_FR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _format,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mois',
          CalendarFormat.week: 'Semaine',
        },
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        eventLoader: _eventsOf,
        onDaySelected: (selected, focused) => setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        }),
        onFormatChanged: (format) => setState(() => _format = format),
        onPageChanged: (focused) {
          final monthChanged = focused.month != _focusedDay.month ||
              focused.year != _focusedDay.year;
          _focusedDay = focused;
          if (monthChanged) {
            _load();
          }
        },
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonShowsNext: false,
          titleTextStyle: theme.titleMedium,
          formatButtonTextStyle: theme.bodySmall,
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: theme.alternate),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: theme.bodySmall.copyWith(color: theme.secondaryText),
          weekendStyle: theme.bodySmall.copyWith(color: theme.secondaryText),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          defaultTextStyle: theme.bodyMedium,
          weekendTextStyle: theme.bodyMedium,
          outsideTextStyle: theme.bodyMedium
              .copyWith(color: theme.secondaryText.withValues(alpha: 0.5)),
          todayDecoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          todayTextStyle:
              theme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          selectedDecoration:
              BoxDecoration(color: theme.primary, shape: BoxShape.circle),
          selectedTextStyle: theme.bodyMedium
              .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) =>
              events.isEmpty ? null : _markers(theme, events),
        ),
      );

  /// Un point par sortie (3 au plus) : or = film, violet = épisode.
  Widget _markers(FlutterFlowTheme theme, List<Map<String, dynamic>> events) {
    return Positioned(
      bottom: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final event in events.take(3))
            Container(
              key: ValueKey('dot-${event['id']}'),
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _colorOf(theme, event),
              ),
            ),
        ],
      ),
    );
  }

  Color _colorOf(FlutterFlowTheme theme, Map<String, dynamic> event) =>
      isEpisodeEvent(event) ? theme.secondary : theme.primary;

  Widget _buildStatus(FlutterFlowTheme theme) {
    final result = _result;
    Widget legend(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: theme.bodySmall),
          ],
        );

    final offline = result != null && result.fromCache && result.error != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          legend(theme.primary, 'Film'),
          const SizedBox(width: 12),
          legend(theme.secondary, 'Épisode'),
          const Spacer(),
          if (offline)
            Flexible(
              child: Text(
                'Hors connexion · enregistré le '
                '${formatReleaseDate(result.updatedAt.toLocal())}',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall.copyWith(color: theme.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayList(FlutterFlowTheme theme) {
    final events = _eventsOf(_selectedDay);
    final Widget content;
    if (events.isEmpty && _busy && _result == null) {
      content = _listShimmer(theme);
    } else if (events.isEmpty && _error != null && _result == null) {
      content = _message(theme, _error!, retry: true);
    } else if (events.isEmpty) {
      content = _message(
          theme,
          _favoritesOnly || _platforms.isNotEmpty
              ? 'Aucune sortie ce jour-là avec ces filtres.'
              : 'Aucune sortie ce jour-là.');
    } else {
      content = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: events.length + 1,
        itemBuilder: (context, index) => index == 0
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '${formatReleaseDate(_selectedDay)} · ${events.length} '
                  'sortie${events.length > 1 ? 's' : ''}',
                  style: theme.titleSmall,
                ),
              )
            : _buildEventTile(theme, events[index - 1]),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _load(force: true),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey('${_selectedDay.toIso8601String()}-${events.length}'),
          child: content,
        ),
      ),
    );
  }

  Widget _message(FlutterFlowTheme theme, String text, {bool retry = false}) =>
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: theme.bodyMedium.copyWith(color: theme.secondaryText)),
          if (retry)
            Center(
              child: TextButton.icon(
                onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ),
        ],
      );

  Widget _buildEventTile(FlutterFlowTheme theme, Map<String, dynamic> event) {
    final release = releaseDateOf(event)!.toLocal();
    final poster = event['poster_url'] as String?;
    final platform = event['platform'] as String?;
    final key = event['id'] as String;
    final hasReminder = _reminders.contains(key);
    final upcoming = release.isAfter(_local.now());
    final mediaId = event['media_key'] as String?;

    // Material : fond et effet du toucher de la tuile ; barre colorée à
    // gauche (or = film, violet = épisode).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: _colorOf(theme, event), width: 4)),
          ),
          child: _tileContent(theme, event, release, poster, platform,
              hasReminder, upcoming, mediaId),
        ),
      ),
    );
  }

  Widget _tileContent(
    FlutterFlowTheme theme,
    Map<String, dynamic> event,
    DateTime release,
    String? poster,
    String? platform,
    bool hasReminder,
    bool upcoming,
    String? mediaId,
  ) {
    return ListTile(
      onTap: widget.onItemTap == null || mediaId == null
          ? null
          : () => widget.onItemTap!(mediaId),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 58,
          child: poster == null || poster.isEmpty
              ? Container(color: theme.alternate)
              : CachedNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: theme.alternate),
                ),
        ),
      ),
      title: Text(
        event['title'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          isEpisodeEvent(event) ? episodeLabel(event) : 'Film',
          _time(release),
          if (platform != null && platform.isNotEmpty) platform,
        ].join(' • '),
        style: theme.bodySmall.copyWith(color: theme.secondaryText),
      ),
      trailing: !upcoming
          ? null
          : hasReminder
              ? IconButton(
                  tooltip: 'Supprimer le rappel',
                  onPressed: () => _toggleReminder(event),
                  icon: Icon(Icons.notifications_active_rounded,
                      color: theme.primary),
                )
              : TextButton.icon(
                  onPressed: () => _toggleReminder(event),
                  icon: const Icon(Icons.notifications_none_rounded, size: 18),
                  label: const Text('Me prévenir'),
                ),
    );
  }

  Widget _calendarShimmer(FlutterFlowTheme theme) => Shimmer.fromColors(
        baseColor: theme.alternate,
        highlightColor: theme.secondaryBackground,
        child: Container(
          height: 300,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.alternate,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  Widget _listShimmer(FlutterFlowTheme theme) => Shimmer.fromColors(
        baseColor: theme.alternate,
        highlightColor: theme.secondaryBackground,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
            3,
            (_) => Container(
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.alternate,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
}
