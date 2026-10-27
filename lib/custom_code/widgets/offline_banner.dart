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

import '/custom_code/actions/cine_sync_service.dart';

/// Bandeau d'état du réseau, à placer en haut d'une page (dans la Column,
/// sans Expanded) : invisible en ligne, « Hors connexion » avec le nombre de
/// modifications en attente, puis « Synchronisation… » et « À jour » au
/// retour du réseau.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({
    super.key,
    this.width,
    this.height,
    this.onBackOnline,
  });

  final double? width;
  final double? height;

  /// Appelé quand la synchronisation est finie au retour du réseau
  /// (ex. rafraîchir la page).
  final Future Function()? onBackOnline;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

enum _BannerPhase { hidden, offline, syncing, synced }

/// Durée d'affichage de « À jour » avant que le bandeau disparaisse.
const Duration kSyncedBannerDuration = Duration(seconds: 3);

class _OfflineBannerState extends State<OfflineBanner> {
  final _subscriptions = <StreamSubscription>[];
  _BannerPhase _phase = _BannerPhase.hidden;
  int _pending = 0;
  int _lastSynced = 0;
  Timer? _hideTimer;

  CineSyncService get _sync => CineSyncService.instance;

  @override
  void initState() {
    super.initState();
    if (!_sync.isOnline) {
      _phase = _BannerPhase.offline;
    }
    _subscriptions
      ..add(_sync.onlineChanges.listen(_onOnline))
      ..add(_sync.events.listen(_onEvent));
    _refreshPending();
    _sync.start();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _refreshPending() async {
    final userId = _sync.remote.currentUserId;
    final count = userId == null
        ? 0
        : await _sync.local.pendingCount(userId: userId).catchError((_) => 0);
    if (mounted) {
      setState(() => _pending = count);
    }
  }

  void _setPhase(_BannerPhase phase) {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() => _phase = phase);
    }
  }

  void _onOnline(bool online) {
    if (!online) {
      _setPhase(_BannerPhase.offline);
      _refreshPending();
    } else if (_phase == _BannerPhase.offline) {
      _setPhase(_BannerPhase.syncing);
    }
  }

  Future<void> _onEvent(SyncEvent event) async {
    if (!mounted) {
      return;
    }
    setState(() => _pending = event.remaining);
    if (event.kind != SyncEventKind.synced || _phase != _BannerPhase.syncing) {
      return;
    }
    if (event.interrupted) {
      _setPhase(_BannerPhase.offline);
      return;
    }
    _lastSynced = event.synced;
    _setPhase(_BannerPhase.synced);
    _hideTimer = Timer(kSyncedBannerDuration, () {
      if (mounted && _phase == _BannerPhase.synced) {
        setState(() => _phase = _BannerPhase.hidden);
      }
    });
    await widget.onBackOnline?.call();
  }

  String get _pendingLabel => _pending == 0
      ? 'Vos données enregistrées restent consultables.'
      : '$_pending modification${_pending > 1 ? 's' : ''} en attente '
          'd\'envoi.';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final (Color color, IconData icon, String title, String? subtitle) =
        switch (_phase) {
      _BannerPhase.offline => (
          theme.warning,
          Icons.cloud_off_rounded,
          'Hors connexion',
          _pendingLabel,
        ),
      _BannerPhase.syncing => (
          theme.primary,
          Icons.sync_rounded,
          'Connexion rétablie',
          'Synchronisation en cours…',
        ),
      _ => (
          theme.success,
          Icons.cloud_done_rounded,
          'À jour',
          _lastSynced == 0
              ? null
              : '$_lastSynced modification${_lastSynced > 1 ? 's' : ''} '
                  'envoyée${_lastSynced > 1 ? 's' : ''}.',
        ),
    };
    final visible = _phase != _BannerPhase.hidden;

    return SizedBox(
      width: widget.width,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: !visible
            ? const SizedBox(width: double.infinity)
            : Semantics(
                liveRegion: true,
                child: AnimatedContainer(
                  key: const ValueKey('offline-banner'),
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: widget.height ?? 0),
                  color: color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title,
                                style: theme.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            if (subtitle != null)
                              Text(subtitle,
                                  style: theme.bodySmall
                                      .copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                      if (_phase == _BannerPhase.syncing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
