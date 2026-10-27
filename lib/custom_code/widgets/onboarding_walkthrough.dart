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

import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/complete_onboarding.dart';

/// Écran de première utilisation (section 6.1) : 4 étapes de présentation
/// puis l'écran Préférences (genres, plateformes, types de contenus,
/// notifications). « Commencer » demande l'autorisation des notifications
/// si elles sont gardées, enregistre les choix (appareil + profil
/// Firestore) puis appelle [onFinish] — dans FlutterFlow, y brancher la
/// navigation vers la HomePage (qui lance la visite guidée).
///
/// Revu depuis Paramètres, l'écran Préférences reprend les choix du profil.
class OnboardingWalkthrough extends StatefulWidget {
  const OnboardingWalkthrough({
    super.key,
    this.width,
    this.height,
    this.onFinish,
  });

  final double? width;
  final double? height;
  final Future Function()? onFinish;

  @override
  State<OnboardingWalkthrough> createState() => _OnboardingWalkthroughState();
}

class _Step {
  const _Step(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

const _steps = [
  _Step(Icons.local_movies_outlined, 'Découvrir',
      'Découvrez les films et séries les plus populaires du moment.'),
  _Step(Icons.manage_search, 'Rechercher',
      'Trouvez rapidement un contenu grâce à la recherche, aux filtres et au tri.'),
  _Step(Icons.favorite_border, 'Organiser',
      'Ajoutez vos films et séries favoris pour les retrouver en un clin d’œil.'),
  _Step(Icons.notifications_active_outlined, 'Ne rien manquer',
      'Recevez une notification à la sortie d’un film ou d’un nouvel épisode.'),
];

const _contentTypeLabels = {
  MediaType.movie: 'Films',
  MediaType.series: 'Séries',
};

class _OnboardingWalkthroughState extends State<OnboardingWalkthrough> {
  final _pageController = PageController();
  int _page = 0;
  List<Genre> _genres = kFallbackGenres;
  List<Platform> _platforms = kFallbackPlatforms;
  final Set<int> _selectedGenres = {};
  final Set<String> _selectedPlatforms = {};
  final Set<MediaType> _contentTypes = {MediaType.movie, MediaType.series};
  bool _notify = true;
  bool _saving = false;

  OnboardingService get _service => OnboardingService.instance;

  int get _pageCount => _steps.length + 1;
  bool get _isLast => _page == _pageCount - 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final genres = await _service.genres();
    final platforms = await _service.platforms();
    final saved = await _service.currentPreferences();
    if (!mounted) {
      return;
    }
    setState(() {
      _genres = genres;
      _platforms = platforms;
      if (saved != null && saved.onboardingCompleted) {
        _selectedGenres.addAll(saved.favoriteGenres);
        _selectedPlatforms.addAll(saved.favoritePlatforms);
        if (saved.contentTypes.isNotEmpty) {
          _contentTypes
            ..clear()
            ..addAll(saved.contentTypes);
        }
        _notify = saved.notificationsEnabled;
      }
    });
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var notify = _notify;
    if (notify) {
      // L'étape 4 a expliqué pourquoi : on demande l'autorisation ici.
      notify = await _service.notifications.init(requestPermission: true);
      if (!notify) {
        messenger?.showSnackBar(const SnackBar(
            content: Text('Notifications refusées : vous pourrez les '
                'activer dans Paramètres.')));
      }
    }
    await _service.complete(OnboardingChoices(
      genreIds: [
        for (final g in _genres)
          if (_selectedGenres.contains(g.id)) g.id,
      ],
      genreNames: [
        for (final g in _genres)
          if (_selectedGenres.contains(g.id)) g.name,
      ],
      platforms: [
        for (final p in _platforms)
          if (_selectedPlatforms.contains(p.name)) p.name,
      ],
      contentTypes: [
        for (final type in MediaType.values)
          if (_contentTypes.contains(type)) type,
      ],
      notificationsEnabled: notify,
    ));
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    await widget.onFinish?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: _isLast ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: _isLast
                      ? null
                      : () => _pageController.animateToPage(
                            _pageCount - 1,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                          ),
                  child: const Text('Passer'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final step in _steps) _buildStep(theme, step),
                  _buildPreferences(theme),
                ],
              ),
            ),
            _buildDots(theme),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saving ? null : (_isLast ? _finish : _next),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isLast ? 'Commencer' : 'Suivant'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(FlutterFlowTheme theme, _Step step) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(step.icon, size: 72, color: theme.primary),
              ),
            ),
            const SizedBox(height: 40),
            Text(step.title,
                style: theme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(
              step.text,
              textAlign: TextAlign.center,
              style: theme.bodyLarge.copyWith(color: theme.secondaryText),
            ),
          ],
        ),
      );

  Widget _chip(FlutterFlowTheme theme, String label, bool selected,
          ValueChanged<bool> onSelected) =>
      FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: theme.primary.withValues(alpha: 0.2),
        checkmarkColor: theme.primary,
        onSelected: onSelected,
      );

  Widget _section(FlutterFlowTheme theme, String title, String? hint) =>
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.titleMedium),
            if (hint != null)
              Text(hint,
                  style: theme.bodySmall.copyWith(color: theme.secondaryText)),
          ],
        ),
      );

  Widget _buildPreferences(FlutterFlowTheme theme) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vos genres préférés', style: theme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Choisissez-en quelques-uns pour personnaliser vos recommandations. '
              'Vous pourrez les modifier plus tard.',
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in _genres)
                  _chip(
                      theme,
                      g.name,
                      _selectedGenres.contains(g.id),
                      (on) => setState(() => on
                          ? _selectedGenres.add(g.id)
                          : _selectedGenres.remove(g.id))),
              ],
            ),
            _section(theme, 'Vos plateformes',
                'Leurs nouveautés vous seront signalées.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _platforms)
                  _chip(
                      theme,
                      p.name,
                      _selectedPlatforms.contains(p.name),
                      (on) => setState(() => on
                          ? _selectedPlatforms.add(p.name)
                          : _selectedPlatforms.remove(p.name))),
              ],
            ),
            _section(theme, 'Types de contenus', null),
            Wrap(
              spacing: 8,
              children: [
                for (final MapEntry(key: type, value: label)
                    in _contentTypeLabels.entries)
                  _chip(
                      theme,
                      label,
                      _contentTypes.contains(type),
                      // Au moins un type reste choisi.
                      (on) => setState(() => on
                          ? _contentTypes.add(type)
                          : _contentTypes.length > 1
                              ? _contentTypes.remove(type)
                              : null)),
              ],
            ),
            const SizedBox(height: 16),
            Material(
              color: theme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                secondary: Icon(Icons.notifications_active_outlined,
                    color: theme.primary),
                title: const Text('Me prévenir des sorties'),
                subtitle: const Text('Nouveaux épisodes de vos séries '
                    'favorites et films de vos plateformes. L’autorisation '
                    'vous sera demandée.'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
            ),
          ],
        ),
      );

  Widget _buildDots(FlutterFlowTheme theme) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _pageCount,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _page ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _page ? theme.primary : theme.alternate,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}
