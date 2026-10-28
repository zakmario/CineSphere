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

import 'package:timeago/timeago.dart' as timeago;

import '/custom_code/actions/cine_notification_service.dart';
import '/custom_code/actions/firebase_service.dart';
import '/custom_code/widgets/fade_slide_in.dart';

/// Page Notifications : notifications remises (`users/{uid}/notifications`),
/// les plus récentes d'abord, paginées au scroll ; marquer comme lu, tout
/// marquer comme lu ; un tap ouvre la fiche du titre.
class NotificationsCenter extends StatefulWidget {
  const NotificationsCenter({
    super.key,
    this.width,
    this.height,
    this.pageSize,
    this.onOpenMedia,
  });

  final double? width;
  final double? height;
  final int? pageSize;

  /// Brancher *Navigate To → MediaDetail* (`mediaId`).
  final Future Function(String mediaId)? onOpenMedia;

  @override
  State<NotificationsCenter> createState() => _NotificationsCenterState();
}

class _NotificationsCenterState extends State<NotificationsCenter> {
  final _scroll = ScrollController();
  final List<NotificationEntry> _items = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  CineNotificationService get _service => CineNotificationService.instance;

  int get _pageSize => (widget.pageSize ?? kPageSize).clamp(5, 50);

  int get _unread => _items.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _scroll.addListener(() {
      final p = _scroll.position;
      if (p.pixels >= p.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _service.store.userId == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.store
          .fetchPage(after: _cursor, pageSize: _pageSize, now: _service.now());
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is CineFailure
              ? e.message
              : 'Impossible de charger les notifications.';
        });
      }
    }
  }

  void _setRead(NotificationEntry entry) {
    final index = _items.indexWhere((n) => n.id == entry.id);
    if (index >= 0) {
      setState(() => _items[index] = _items[index].copyWith(isRead: true));
    }
  }

  Future<void> _markRead(NotificationEntry entry) async {
    if (entry.isRead) {
      return;
    }
    _setRead(entry);
    try {
      await _service.store.markRead(entry.id);
    } catch (e) {
      debugPrint('markRead : $e');
    }
  }

  Future<void> _markAllRead() async {
    final unread = _items.where((n) => !n.isRead).toList();
    for (final entry in unread) {
      _setRead(entry);
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.store.markAllRead(now: _service.now());
      messenger.showSnackBar(SnackBar(
          content: Text('${unread.length} notification'
              '${unread.length > 1 ? 's marquées' : ' marquée'} comme lue'
              '${unread.length > 1 ? 's' : ''}')));
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Impossible de tout marquer.')));
    }
  }

  Future<void> _open(NotificationEntry entry) async {
    await _markRead(entry);
    final key = entry.mediaKeyValue;
    if (key != null) {
      await widget.onOpenMedia?.call(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          _buildHeader(theme),
          Expanded(
              child: cineStateSwitcher(context, _state, _buildBody(theme))),
        ],
      ),
    );
  }

  Widget _buildHeader(FlutterFlowTheme theme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _unread == 0
                    ? 'Tout est lu'
                    : '$_unread non lue${_unread > 1 ? 's' : ''}',
                style: theme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: _unread == 0 ? null : _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Tout marquer comme lu'),
            ),
          ],
        ),
      );

  /// État affiché (fondu enchaîné quand il change).
  String get _state => _service.store.userId == null
      ? 'signed-out'
      : _items.isNotEmpty
          ? 'list'
          : _loading
              ? 'loading'
              : _error != null
                  ? 'error'
                  : 'empty';

  Widget _buildBody(FlutterFlowTheme theme) {
    if (_service.store.userId == null) {
      return _message(theme, Icons.lock_outline_rounded,
          'Connectez-vous pour voir vos notifications.');
    }
    if (_items.isEmpty && _loading) {
      return const CineSkeleton(variant: 'list', itemCount: 6);
    }
    if (_items.isEmpty && _error != null) {
      return _message(theme, Icons.cloud_off_rounded, _error!, retry: true);
    }
    if (_items.isEmpty) {
      return _message(
          theme,
          Icons.notifications_none_rounded,
          'Aucune notification pour l\'instant. Touchez « Me prévenir » '
          'dans le calendrier pour programmer un rappel.');
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => Divider(height: 1, color: theme.alternate),
        itemBuilder: (context, index) => index == _items.length
            ? _buildFooter(theme)
            : FadeSlideIn(
                index: index,
                // Pages suivantes (scroll) : pas de cascade.
                enabled: index < _pageSize,
                child: _buildTile(theme, _items[index]),
              ),
      ),
    );
  }

  Widget _buildTile(FlutterFlowTheme theme, NotificationEntry entry) {
    final (IconData icon, Color color) = switch (entry.mediaType) {
      'movie' => (Icons.movie_rounded, theme.primary),
      'series' => (Icons.live_tv_rounded, theme.secondary),
      _ => (Icons.notifications_rounded, theme.secondaryText),
    };
    final date = entry.date;
    return Material(
      color: entry.isRead
          ? Colors.transparent
          : theme.primary.withValues(alpha: 0.08),
      child: ListTile(
        onTap: () => _open(entry),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.bodyMedium.copyWith(
              fontWeight: entry.isRead ? FontWeight.normal : FontWeight.w700),
        ),
        subtitle: Text(
          [
            entry.message,
            if (date != null)
              timeago.format(date, locale: 'fr', clock: _service.now()),
          ].join('\n'),
          style: theme.bodySmall.copyWith(color: theme.secondaryText),
        ),
        isThreeLine: date != null,
        trailing: entry.isRead
            ? null
            : IconButton(
                tooltip: 'Marquer comme lu',
                onPressed: () => _markRead(entry),
                icon: Icon(Icons.circle, size: 12, color: theme.primary),
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
            onPressed: _loadMore, child: const Text('Erreur — réessayer')),
      );
    }
    return const SizedBox(height: 32);
  }

  Widget _message(FlutterFlowTheme theme, IconData icon, String text,
          {bool retry = false}) =>
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(icon, size: 56, color: theme.secondaryText),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: theme.bodyMedium.copyWith(color: theme.secondaryText)),
          if (retry)
            Center(
              child: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ),
        ],
      );
}
