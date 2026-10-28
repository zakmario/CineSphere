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

import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/firebase_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Section « Préférences » de la page Paramètres (membre 1, section 6.11) :
/// thème clair / sombre / système, types de contenus, genres et plateformes
/// préférés (enregistrés dans `users/{uid}.preferences`), vider le cache.
class PreferencesPanel extends StatefulWidget {
  const PreferencesPanel({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<PreferencesPanel> createState() => _PreferencesPanelState();
}

AppThemeMode _appMode(ThemeMode mode) => switch (mode) {
      ThemeMode.light => AppThemeMode.light,
      ThemeMode.dark => AppThemeMode.dark,
      ThemeMode.system => AppThemeMode.system,
    };

class _PreferencesPanelState extends State<PreferencesPanel> {
  CineFirebaseService get _service => CineFirebaseService.instance;

  UserPreferences? _prefs;
  List<Genre> _genres = const [];
  List<Platform> _platforms = const [];
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;
  bool _loading = true;
  String? _error;
  Timer? _pendingSave;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    // Un choix fait juste avant de quitter la page est quand même enregistré.
    if (_pendingSave?.isActive ?? false) {
      _pendingSave!.cancel();
      unawaited(_save(showError: false));
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    if (_service.currentUserId == null) {
      setState(() {
        _loading = false;
        _error = 'Connectez-vous pour régler vos préférences.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _service.fetchPreferences(),
        _service.fetchGenres(),
        _service.fetchPlatforms(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _prefs = results[0] as UserPreferences;
        _genres = results[1] as List<Genre>;
        _platforms = results[2] as List<Platform>;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is CineFailure
              ? error.message
              : 'Impossible de charger vos préférences.';
        });
      }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Change les préférences tout de suite et les enregistre peu après :
  /// plusieurs choix rapprochés ne font qu'une écriture.
  void _update(UserPreferences prefs) {
    setState(() => _prefs = prefs);
    _pendingSave?.cancel();
    _pendingSave = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save({bool showError = true}) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _service.savePreferences(prefs);
      // « Pour vous » (HomeFeed) lit les genres par leur nom.
      final names = [
        for (final genre in _genres)
          if (prefs.favoriteGenres.contains(genre.id)) genre.name,
      ];
      final local = await SharedPreferences.getInstance();
      await local.setStringList('cs_favorite_genres', names);
    } catch (error) {
      if (showError && mounted) {
        _snack(error is CineFailure
            ? error.message
            : 'Impossible d\'enregistrer vos préférences.');
      }
    }
  }

  void _setTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _applyTheme(mode);
    final prefs = _prefs;
    if (prefs != null) {
      _update(prefs.copyWith(themeMode: _appMode(mode)));
    }
  }

  /// Équivaut à setDarkModeSetting de flutter_flow_util, que l'éditeur
  /// FlutterFlow ne fournit pas au code personnalisé : appelle
  /// setThemeMode de l'état de MyApp (main.dart), qui enregistre aussi le
  /// choix. Sans MyApp (tests), ne fait rien.
  void _applyTheme(ThemeMode mode) {
    State? app;
    context.visitAncestorElements((element) {
      if (element is StatefulElement &&
          element.state.runtimeType.toString() == '_MyAppState') {
        app = element.state;
        return false;
      }
      return true;
    });
    try {
      (app as dynamic)?.setThemeMode(mode);
    } catch (error) {
      debugPrint('PreferencesPanel: $error');
    }
  }

  Future<void> _clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {
      // Cache disque indisponible (web) : on vide au moins la mémoire.
    }
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _service.invalidateCatalog();
    await clearLocalCache(); // cache SQLite (membre 3)
    if (mounted) {
      _snack('Cache vidé : affiches et catalogue seront rechargés.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final children = <Widget>[
      _label(theme, 'Thème'),
      SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Sombre')),
          ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Clair')),
          ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('Système')),
        ],
        selected: {_themeMode},
        onSelectionChanged: (selection) => _setTheme(selection.first),
      ),
    ];

    if (_loading) {
      children.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ));
    } else if (_error != null) {
      children.addAll([
        const SizedBox(height: 12),
        Text(_error!, style: theme.bodyMedium),
        if (_service.currentUserId != null)
          TextButton(onPressed: _load, child: const Text('Réessayer')),
      ]);
    } else {
      final prefs = _prefs!;
      children.addAll([
        _label(theme, 'Je regarde'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final type in MediaType.values)
            FilterChip(
              label: Text(type == MediaType.movie ? 'Films' : 'Séries'),
              selected: prefs.contentTypes.contains(type),
              onSelected: (on) {
                // _prefs et non prefs : deux appuis avant de redessiner ne
                // doivent pas s'écraser.
                final current = _prefs!;
                final types = {...current.contentTypes};
                on ? types.add(type) : types.remove(type);
                // Au moins un type reste choisi.
                if (types.isNotEmpty) {
                  _update(current.copyWith(contentTypes: types.toList()));
                }
              },
            ),
        ]),
        _label(theme, 'Genres préférés'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final genre in _genres)
            FilterChip(
              label: Text(genre.name),
              selected: prefs.favoriteGenres.contains(genre.id),
              onSelected: (on) {
                final current = _prefs!;
                final ids = [...current.favoriteGenres]..remove(genre.id);
                if (on) {
                  ids.add(genre.id);
                }
                _update(current.copyWith(favoriteGenres: ids));
              },
            ),
        ]),
        _label(theme, 'Plateformes préférées'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final platform in _platforms)
            FilterChip(
              label: Text(platform.name),
              selected: prefs.favoritePlatforms.contains(platform.name),
              onSelected: (on) {
                final current = _prefs!;
                final names = [...current.favoritePlatforms]
                  ..remove(platform.name);
                if (on) {
                  names.add(platform.name);
                }
                _update(current.copyWith(favoritePlatforms: names));
              },
            ),
        ]),
      ]);
    }

    children.addAll([
      _label(theme, 'Stockage'),
      OutlinedButton.icon(
        onPressed: _clearCache,
        icon: const Icon(Icons.cleaning_services_outlined),
        label: const Text('Vider le cache'),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Affiches enregistrées et catalogue gardé en mémoire.',
          style: theme.bodySmall.copyWith(color: theme.secondaryText),
        ),
      ),
    ]);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _label(FlutterFlowTheme theme, String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: theme.titleSmall.copyWith(color: theme.secondaryText)),
      );
}
