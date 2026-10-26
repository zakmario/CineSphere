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
import 'package:shared_preferences/shared_preferences.dart';

/// Contenu complet de la page d'accueil : sections horizontales
/// « Pour vous » (genres choisis pendant le walkthrough), « Tendances »,
/// « Bientôt disponible » et « Les mieux notés ».
class HomeFeed extends StatefulWidget {
  const HomeFeed({
    super.key,
    this.width,
    this.height,
    this.onItemTap,
    this.onOnboardingRequired,
  });

  final double? width;
  final double? height;
  final Future Function(String tappedMediaId)? onItemTap;

  /// Appelé au chargement si l'utilisateur n'a jamais vu le walkthrough :
  /// brancher ici "Navigate To → Onboarding".
  final Future Function()? onOnboardingRequired;

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _Section {
  _Section(this.title, this.icon, this.items);
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
}

class _HomeFeedState extends State<HomeFeed> {
  List<_Section> _sections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.onOnboardingRequired != null &&
          !await hasCompletedOnboarding()) {
        await widget.onOnboardingRequired!();
        return;
      }
      await _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final genres = prefs.getStringList('cs_favorite_genres') ?? <String>[];
      final media = await CineFirebaseService.instance.catalog();

      /// Les 10 premiers titres retenus par [keep], triés par [key].
      List<Map<String, dynamic>> top(
        bool Function(Map<String, dynamic> row) keep,
        String key, {
        bool ascending = false,
      }) {
        final rows = media.where((r) => keep(r) && r[key] != null).toList()
          ..sort((a, b) {
            final c = (a[key] as Comparable).compareTo(b[key] as Comparable);
            return ascending ? c : -c;
          });
        return rows.take(10).toList();
      }

      final results = [
        genres.isEmpty
            ? <Map<String, dynamic>>[]
            : top(
                (r) =>
                    r['status'] != 'upcoming' &&
                    ((r['genres'] as List?) ?? []).any(genres.contains),
                'rating'),
        top((_) => true, 'popularity'),
        top((r) => r['status'] == 'upcoming', 'release_date', ascending: true),
        top((r) => ((r['rating'] as num?) ?? 0) > 0, 'rating'),
      ];

      if (!mounted) {
        return;
      }
      setState(() {
        _sections = [
          _Section('Pour vous', Icons.auto_awesome, results[0]),
          _Section('Tendances', Icons.local_fire_department, results[1]),
          _Section('Bientôt disponible', Icons.event, results[2]),
          _Section('Les mieux notés', Icons.star, results[3]),
        ].where((s) => s.items.isNotEmpty).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger l’accueil.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget body;
    if (_loading && _sections.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _sections.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 56, color: theme.secondaryText),
            const SizedBox(height: 12),
            Text(_error!, style: theme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final section in _sections) _buildSection(theme, section),
          ],
        ),
      );
    }
    return SizedBox(width: widget.width, height: widget.height, child: body);
  }

  Widget _buildSection(FlutterFlowTheme theme, _Section section) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              children: [
                Icon(section.icon, color: theme.primary, size: 22),
                const SizedBox(width: 8),
                Text(section.title, style: theme.titleMedium),
              ],
            ),
          ),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: section.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = section.items[index];
                final id = item['id'] as String;
                return MediaCard(
                  key: ValueKey('${section.title}-$id'),
                  width: 130,
                  title: item['title'] as String? ?? '',
                  posterUrl: item['poster_url'] as String?,
                  mediaType: item['media_type'] as String?,
                  rating: (item['rating'] as num?)?.toDouble(),
                  releaseDate: item['release_date'] == null
                      ? null
                      : DateTime.tryParse(item['release_date'] as String),
                  onTap: widget.onItemTap == null
                      ? null
                      : () => widget.onItemTap!(id),
                );
              },
            ),
          ),
        ],
      );
}
