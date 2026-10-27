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

import '/custom_code/actions/firebase_service.dart';

/// Statistiques personnelles de la page Profil (membre 1, section 6.11) :
/// films vus, séries suivies, heures de visionnage, genre préféré. Se met à
/// jour quand un favori ou un « vu » change.
class ProfileStats extends StatefulWidget {
  const ProfileStats({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<ProfileStats> createState() => _ProfileStatsState();
}

/// 0 -> « 0 h », 45 -> « 45 min », 135 -> « 2 h 15 ».
String watchTimeLabel(int minutes) {
  if (minutes <= 0) {
    return '0 h';
  }
  if (minutes < 60) {
    return '$minutes min';
  }
  final rest = minutes % 60;
  return rest == 0
      ? '${minutes ~/ 60} h'
      : '${minutes ~/ 60} h ${rest.toString().padLeft(2, '0')}';
}

class _ProfileStatsState extends State<ProfileStats> {
  UserStats? _stats;
  bool _loading = true;
  String? _error;
  StreamSubscription<MediaChange>? _changes;
  Timer? _reload;

  @override
  void initState() {
    super.initState();
    _changes = CineFirebaseService.instance.mediaChanges.listen((_) {
      // Plusieurs changements rapprochés : un seul rechargement.
      _reload?.cancel();
      _reload = Timer(const Duration(milliseconds: 600), _load);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    _reload?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    if (CineFirebaseService.instance.currentUserId == null) {
      setState(() {
        _stats = const UserStats();
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = _stats == null;
      _error = null;
    });
    try {
      final stats = await CineFirebaseService.instance.fetchMyStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is CineFailure
              ? error.message
              : 'Impossible de calculer vos statistiques.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget body;
    if (_loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_error != null && _stats == null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: theme.bodyMedium, textAlign: TextAlign.center),
          TextButton(onPressed: _load, child: const Text('Réessayer')),
        ],
      );
    } else {
      final stats = _stats!;
      final tiles = [
        _StatTile(
          icon: Icons.movie_outlined,
          color: theme.primary,
          value: '${stats.moviesWatched}',
          label: 'Films vus',
        ),
        _StatTile(
          icon: Icons.tv_rounded,
          color: theme.secondary,
          value: '${stats.seriesFollowed}',
          label: 'Séries suivies',
        ),
        _StatTile(
          icon: Icons.schedule_rounded,
          color: theme.success,
          value: watchTimeLabel(stats.watchMinutes),
          label: 'De visionnage',
          hint: stats.seriesWatched > 0
              ? 'Séries : $kEpisodeMinutes min par épisode'
              : null,
        ),
        _StatTile(
          icon: Icons.local_movies_outlined,
          color: theme.warning,
          value: stats.favoriteGenre ?? '—',
          label: 'Genre préféré',
        ),
      ];
      body = LayoutBuilder(builder: (context, constraints) {
        // 4 colonnes sur tablette, 2 sur téléphone.
        // Largeur non bornée (Row, colonne centrée) : largeur de téléphone.
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final columns = maxWidth >= 600 ? 4 : 2;
        final width = (maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      });
    }
    return SizedBox(width: widget.width, height: widget.height, child: body);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.hint,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final tile = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.headlineSmall,
          ),
          Text(label,
              style: theme.bodySmall.copyWith(color: theme.secondaryText)),
        ],
      ),
    );
    return hint == null ? tile : Tooltip(message: hint!, child: tile);
  }
}
