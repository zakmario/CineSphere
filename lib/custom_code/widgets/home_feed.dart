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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contenu complet de la page d'accueil : carrousel « À la une » (les 5
/// tendances, image large), puis sections horizontales « Pour vous »
/// (genres choisis pendant le walkthrough), « Tendances », « Bientôt
/// disponible » et « Les mieux notés ».
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
  List<Map<String, dynamic>> _featured = [];
  bool _loading = true;
  String? _error;

  final _heroController = PageController(viewportFraction: 0.92);
  int _heroPage = 0;
  Timer? _heroTimer;

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  /// Le carrousel avance seul toutes les 6 s.
  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (_featured.length < 2) {
      return;
    }
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_heroController.hasClients) {
        return;
      }
      _heroController.animateToPage(
        (_heroPage + 1) % _featured.length,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

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
        _featured = results[1].take(5).toList();
        _sections = [
          _Section('Pour vous', Icons.auto_awesome, results[0]),
          _Section('Tendances', Icons.local_fire_department, results[1]),
          _Section('Bientôt disponible', Icons.event, results[2]),
          _Section('Les mieux notés', Icons.star, results[3]),
        ].where((s) => s.items.isNotEmpty).toList();
        _loading = false;
      });
      _startHeroTimer();
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
      body = ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 210,
              decoration: BoxDecoration(
                color: theme.alternate,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const CineSkeleton(variant: 'row'),
          const SizedBox(height: 28),
          const CineSkeleton(variant: 'row'),
        ],
      );
    } else if (_error != null && _sections.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded,
                    size: 40, color: theme.primary),
              ),
              const SizedBox(height: 20),
              Text(_error!,
                  style:
                      theme.titleMedium.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Vérifiez votre connexion puis réessayez.',
                  style: theme.bodyMedium.copyWith(color: theme.secondaryText),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        color: theme.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (_featured.isNotEmpty) _buildHero(theme),
            for (final section in _sections) _buildSection(theme, section),
          ],
        ),
      );
    }
    return SizedBox(width: widget.width, height: widget.height, child: body);
  }

  /// Carrousel « À la une » : image large, dégradé, titre et note.
  Widget _buildHero(FlutterFlowTheme theme) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: _heroController,
                itemCount: _featured.length,
                onPageChanged: (i) => setState(() => _heroPage = i),
                itemBuilder: (context, index) =>
                    _buildHeroItem(theme, _featured[index], index),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _featured.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _heroPage ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _heroPage ? theme.primary : theme.alternate,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _buildHeroItem(
      FlutterFlowTheme theme, Map<String, dynamic> item, int index) {
    final id = item['id'] as String;
    final backdrop = item['backdrop_url'] as String?;
    final image = backdrop != null && backdrop.isNotEmpty
        ? backdrop
        : item['poster_url'] as String?;
    final rating = (item['rating'] as num?)?.toDouble();
    final date = item['release_date'] == null
        ? null
        : DateTime.tryParse(item['release_date'] as String);
    final meta = [
      mediaTypeLabel(item['media_type'] as String?),
      if (date != null) '${date.year}',
      if (rating != null && rating > 0) '★ ${ratingLabel(rating)}',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: widget.onItemTap == null ? null : () => widget.onItemTap!(id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null && image.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ColoredBox(color: theme.alternate),
                    errorWidget: (_, __, ___) =>
                        ColoredBox(color: theme.alternate),
                  )
                else
                  ColoredBox(color: theme.alternate),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xD9000000)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'TENDANCE #${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item['title'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.headlineSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meta,
                              style: theme.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: theme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(FlutterFlowTheme theme, _Section section) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(section.icon, color: theme.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: theme.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                    ),
                  ),
                ),
                Text(
                  '${section.items.length} titres',
                  style: theme.labelMedium.copyWith(color: theme.secondaryText),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: section.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = section.items[index];
                final id = item['id'] as String;
                return MediaCard(
                  key: ValueKey('${section.title}-$id'),
                  width: 136,
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
