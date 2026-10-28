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

import '/custom_code/actions/firebase_service.dart';
import '/custom_code/widgets/fade_slide_in.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Calendrier des prochaines sorties (table `release_events`), groupé par jour,
/// paginé au scroll, avec une cloche par sortie qui programme / annule une
/// notification locale.
class UpcomingReleasesList extends StatefulWidget {
  const UpcomingReleasesList({
    super.key,
    this.width,
    this.height,
    this.mediaId,
    this.pageSize,
    this.reminderMinutesBefore,
    this.onItemTap,
  });

  final double? width;
  final double? height;

  /// Si renseigné, n'affiche que les sorties de ce contenu (page détail).
  final String? mediaId;
  final int? pageSize;

  /// Délai du rappel avant la sortie (60 minutes par défaut).
  final int? reminderMinutesBefore;
  final Future Function(String selectedMediaId)? onItemTap;

  @override
  State<UpcomingReleasesList> createState() => _UpcomingReleasesListState();
}

class _UpcomingReleasesListState extends State<UpcomingReleasesList> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _events = [];
  Set<String> _reminders = {};
  bool _loading = false;
  bool _hasMore = true;

  /// Dernier document chargé : la page suivante commence après lui.
  DocumentSnapshot? _lastDoc;
  String? _error;

  int get _pageSize => (widget.pageSize ?? 15).clamp(5, 100);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final p = _scrollController.position;
      if (p.pixels >= p.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReminders();
      _loadMore();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final keys = await getScheduledReminders();
    if (mounted) {
      setState(() => _reminders = keys.toSet());
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _events.clear();
      _lastDoc = null;
      _hasMore = true;
      _error = null;
    });
    await _loadReminders();
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (!mounted || _loading || !_hasMore) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Query<Map<String, dynamic>> query =
          CineFirebaseService.instance.col('releaseEvents');
      final target = parseMediaKey(widget.mediaId);
      if (target != null) {
        query = query
            .where('mediaType', isEqualTo: target.type)
            .where('tmdbId', isEqualTo: target.tmdbId);
      }
      query = query
          .where('releaseDate', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('releaseDate')
          .limit(_pageSize);
      final last = _lastDoc;
      if (last != null) {
        query = query.startAfterDocument(last);
      }
      final page = await query.get();
      // Titre et affiche sont dénormalisés dans l'événement (section 5.2).
      final rows = [
        for (final doc in page.docs)
          () {
            final row = cineRow(doc);
            return row
              ..['release_at'] = row['release_date']
              ..['media'] = {
                'id': mediaKey(
                    row['media_type'] as String, row['tmdb_id'] as int),
                'title': row['title'],
                'poster_url': row['poster_url'],
                'media_type': row['media_type'],
              };
          }(),
      ];
      if (!mounted) {
        return;
      }
      setState(() {
        if (page.docs.isNotEmpty) {
          _lastDoc = page.docs.last;
        }
        _events.addAll(rows);
        _hasMore = page.docs.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger le calendrier.';
        });
      }
    }
  }

  Future<void> _toggleReminder(Map<String, dynamic> event) async {
    final key = event['id'] as String;
    // Le nouveau message remplace le précédent au lieu d'attendre derrière.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    if (_reminders.contains(key)) {
      await cancelReleaseNotification(key);
      if (!mounted) {
        return;
      }
      setState(() => _reminders.remove(key));
      messenger.showSnackBar(const SnackBar(content: Text('Rappel supprimé')));
      return;
    }

    final releaseAt = DateTime.parse(event['release_at'] as String).toLocal();
    var remindAt = releaseAt
        .subtract(Duration(minutes: widget.reminderMinutesBefore ?? 60));
    // Sortie très proche : on prévient au moment de la sortie.
    if (!remindAt.isAfter(DateTime.now())) {
      remindAt = releaseAt;
    }
    final media = event['media'] as Map<String, dynamic>?;
    final mediaTitle = media?['title'] as String? ?? 'Nouvelle sortie';
    final ok = await scheduleReleaseNotification(
      key,
      mediaTitle,
      '${event['title']} — ${releaseCountdownLabel(releaseAt).toLowerCase()}'
      '${event['platform'] != null ? ' sur ${event['platform']}' : ''}',
      remindAt,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      setState(() => _reminders.add(key));
    }
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Rappel programmé le ${formatReleaseDate(remindAt)} à '
              '${remindAt.hour.toString().padLeft(2, '0')}:'
              '${remindAt.minute.toString().padLeft(2, '0')}'
          : 'Impossible de programmer le rappel (permission refusée ?)'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: cineStateSwitcher(context, _state, _buildBody(theme)),
    );
  }

  /// État affiché (fondu enchaîné quand il change).
  String get _state => _events.isNotEmpty
      ? 'list'
      : _loading
          ? 'loading'
          : _error != null
              ? 'error'
              : _hasMore
                  ? 'loading'
                  : 'empty';

  Widget _buildBody(FlutterFlowTheme theme) {
    if (_events.isEmpty && (_loading || (_error == null && _hasMore))) {
      return const CineSkeleton(variant: 'list', itemCount: 6);
    }
    if (_events.isEmpty && _error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    if (_events.isEmpty && !_hasMore) {
      return Center(
        child: Text('Aucune sortie prévue pour le moment.',
            style: theme.bodyMedium),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _events.length + 1,
        itemBuilder: (context, index) {
          if (index == _events.length) {
            return _buildFooter(theme);
          }
          final event = _events[index];
          final date = DateTime.parse(event['release_at'] as String).toLocal();
          final previous = index == 0
              ? null
              : DateTime.parse(_events[index - 1]['release_at'] as String)
                  .toLocal();
          final newDay = previous == null ||
              previous.year != date.year ||
              previous.month != date.month ||
              previous.day != date.day;
          return FadeSlideIn(
            index: index,
            // Pages suivantes (scroll) : pas de cascade.
            enabled: index < _pageSize,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (newDay) _buildDayHeader(theme, date),
                _buildEventTile(theme, event, date),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayHeader(FlutterFlowTheme theme, DateTime date) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            // Écran étroit ou grand texte : la date se tronque, sans
            // déborder.
            Flexible(
              child: Text(formatReleaseDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isReleaseSoon(date, 1) ? theme.primary : theme.alternate,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                releaseCountdownLabel(date),
                style: theme.bodySmall.copyWith(
                  color:
                      isReleaseSoon(date, 1) ? Colors.white : theme.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildEventTile(
    FlutterFlowTheme theme,
    Map<String, dynamic> event,
    DateTime date,
  ) {
    final media = event['media'] as Map<String, dynamic>?;
    final poster = media?['poster_url'] as String?;
    final hasReminder = _reminders.contains(event['id']);
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return ListTile(
      onTap: widget.onItemTap == null || media == null
          ? null
          : () => widget.onItemTap!(media['id'] as String),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 64,
          child: poster == null
              ? Container(color: theme.alternate)
              : CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
        ),
      ),
      title: Text(
        media?['title'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          event['title'],
          time,
          if (event['platform'] != null) event['platform'],
        ].join(' • '),
        style: theme.bodySmall.copyWith(color: theme.secondaryText),
      ),
      trailing: IconButton(
        tooltip: hasReminder ? 'Supprimer le rappel' : 'Me le rappeler',
        onPressed: () => _toggleReminder(event),
        icon: Icon(
          hasReminder ? Icons.notifications_active : Icons.notifications_none,
          color: hasReminder ? theme.primary : theme.secondaryText,
        ),
      ),
    );
  }

  Widget _buildFooter(FlutterFlowTheme theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: _loadMore,
          child: const Text('Erreur — réessayer'),
        ),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text('Fin du calendrier',
              style: theme.bodySmall.copyWith(color: theme.secondaryText)),
        ),
      );
    }
    return const SizedBox(height: 32);
  }
}
