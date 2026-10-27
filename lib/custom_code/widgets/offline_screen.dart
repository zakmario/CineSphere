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

import 'package:shimmer/shimmer.dart';

import '/custom_code/actions/cine_local_db.dart';
import '/custom_code/actions/cine_sync_service.dart';

/// Écran « Hors connexion » (page HorsConnexion) : ce qui reste consultable
/// grâce au cache SQLite (favoris, catalogue enregistré), les modifications
/// en attente et un bouton « Réessayer ». [onBackOnline] est appelé dès que
/// le réseau revient (ex. *Navigate Back*).
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({
    super.key,
    this.width,
    this.height,
    this.onBackOnline,
    this.onItemTap,
  });

  final double? width;
  final double? height;
  final Future Function()? onBackOnline;
  final Future Function(String mediaId)? onItemTap;

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

/// Titres du catalogue affichés hors connexion (les plus populaires).
const int kOfflineCatalogLimit = 30;

class _OfflineScreenState extends State<OfflineScreen> {
  StreamSubscription<bool>? _subscription;
  bool _loading = true;
  bool _checking = false;
  bool _leaving = false;
  List<Map<String, dynamic>> _favorites = const [];
  List<Map<String, dynamic>> _catalog = const [];
  DateTime? _cachedAt;
  int _pending = 0;

  CineSyncService get _sync => CineSyncService.instance;

  @override
  void initState() {
    super.initState();
    _subscription = _sync.onlineChanges.listen((online) {
      if (online) {
        _backOnline();
      }
    });
    _sync.start();
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final local = _sync.local;
    final userId = _sync.remote.currentUserId;
    try {
      final catalog = await local.readCatalog();
      final favorites = userId == null
          ? const <Map<String, dynamic>>[]
          : await local.localFavorites(userId);
      final pending =
          userId == null ? 0 : await local.pendingCount(userId: userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _catalog =
            (catalog?.value ?? const []).take(kOfflineCatalogLimit).toList();
        _cachedAt = catalog?.cachedAt;
        _favorites = favorites;
        _pending = pending;
        _loading = false;
      });
    } catch (e) {
      debugPrint('OfflineScreen: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _backOnline() async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    await widget.onBackOnline?.call();
  }

  Future<void> _retry() async {
    setState(() => _checking = true);
    final online = await _sync.checkConnection();
    if (!mounted) {
      return;
    }
    setState(() => _checking = false);
    if (online) {
      await _backOnline();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Toujours hors connexion. Vérifiez le Wi-Fi ou '
              'les données mobiles.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RefreshIndicator(
        onRefresh: _retry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            _buildHeader(theme),
            const SizedBox(height: 24),
            if (_loading)
              _buildShimmer(theme)
            else if (_favorites.isEmpty && _catalog.isEmpty)
              _buildEmpty(theme)
            else ...[
              if (_favorites.isNotEmpty) ...[
                _sectionTitle(theme, 'Mes favoris', Icons.favorite_rounded),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) =>
                        _card(_favorites[i], width: 120, height: 210),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (_catalog.isNotEmpty) ...[
                _sectionTitle(
                    theme, 'Catalogue enregistré', Icons.download_done_rounded),
                if (_cachedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Mis à jour le ${formatReleaseDate(_cachedAt!.toLocal())}',
                      style:
                          theme.bodySmall.copyWith(color: theme.secondaryText),
                    ),
                  ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.55,
                  ),
                  itemCount: _catalog.length,
                  itemBuilder: (_, i) => _card(_catalog[i]),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FlutterFlowTheme theme) => Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: theme.secondaryText),
          const SizedBox(height: 12),
          Text('Vous êtes hors connexion',
              textAlign: TextAlign.center, style: theme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Les contenus ci-dessous sont enregistrés sur votre appareil. '
            'Vos modifications seront envoyées au retour du réseau.',
            textAlign: TextAlign.center,
            style: theme.bodyMedium.copyWith(color: theme.secondaryText),
          ),
          if (_pending > 0) ...[
            const SizedBox(height: 12),
            Chip(
              avatar:
                  Icon(Icons.schedule_rounded, size: 18, color: theme.primary),
              label: Text('$_pending modification${_pending > 1 ? 's' : ''} '
                  'en attente'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _checking ? null : _retry,
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      );

  Widget _sectionTitle(FlutterFlowTheme theme, String title, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.primary),
            const SizedBox(width: 8),
            Text(title, style: theme.titleMedium),
          ],
        ),
      );

  Widget _card(Map<String, dynamic> row, {double? width, double? height}) {
    final id = row['id'] as String? ?? '';
    return MediaCard(
      width: width,
      height: height,
      title: row['title'] as String? ?? '',
      posterUrl: row['poster_url'] as String?,
      mediaType: row['media_type'] as String?,
      rating: (row['rating'] as num?)?.toDouble(),
      releaseDate: DateTime.tryParse('${row['release_date'] ?? ''}'),
      onTap: widget.onItemTap == null ? null : () => widget.onItemTap!(id),
    );
  }

  Widget _buildEmpty(FlutterFlowTheme theme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          _sync.local.isSupported
              ? 'Aucun contenu enregistré pour l\'instant. Ouvrez '
                  'l\'application une fois connecté pour remplir le cache.'
              : 'Le cache hors connexion n\'est disponible que dans '
                  'l\'application Android / iOS.',
          textAlign: TextAlign.center,
          style: theme.bodyMedium.copyWith(color: theme.secondaryText),
        ),
      );

  Widget _buildShimmer(FlutterFlowTheme theme) => Shimmer.fromColors(
        baseColor: theme.alternate,
        highlightColor: theme.secondaryBackground,
        child: Wrap(
          spacing: 12,
          runSpacing: 16,
          children: List.generate(
            6,
            (_) => Container(
              width: 100,
              height: 150,
              decoration: BoxDecoration(
                color: theme.alternate,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
}
