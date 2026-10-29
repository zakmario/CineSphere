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

import '/custom_code/actions/app_tour.dart';
import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/complete_onboarding.dart';

/// Écran de première utilisation (section 6.1) : 4 étapes de présentation
/// puis l'écran Préférences (genres, plateformes, types de contenus,
/// notifications). « Commencer » demande l'autorisation des notifications
/// si elles sont gardées, enregistre les choix (appareil + profil
/// Firestore) puis appelle [onFinish] — dans FlutterFlow, y brancher la
/// navigation vers la HomePage. Le guide de l'application ([AppTour]) se
/// lance ensuite sur la page qui affiche la barre de navigation.
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
  _Step(Icons.local_movies_rounded, 'Découvrir',
      'Découvrez les films et séries les plus populaires du moment.'),
  _Step(Icons.manage_search_rounded, 'Rechercher',
      'Trouvez rapidement un contenu grâce à la recherche, aux filtres et au tri.'),
  _Step(Icons.favorite_rounded, 'Organiser',
      'Ajoutez vos films et séries favoris pour les retrouver en un clin d’œil.'),
  _Step(Icons.notifications_active_rounded, 'Ne rien manquer',
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

  void _back() {
    _pageController.previousPage(
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
    unawaited(AppTour.startAfterOnboarding());
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(theme.primary.withValues(alpha: 0.10),
                  theme.primaryBackground),
              theme.primaryBackground,
            ],
            stops: const [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(theme),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildProgress(theme),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final (i, step) in _steps.indexed)
                      _buildStep(theme, step, i),
                    _buildPreferences(theme),
                  ],
                ),
              ),
              _buildDots(theme),
              _buildActions(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(FlutterFlowTheme theme) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: _gradient(theme),
              ),
              child: const Icon(Icons.movie_filter_rounded,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('CinéSphère',
                style: theme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            AnimatedOpacity(
              opacity: _isLast ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: TextButton(
                style:
                    TextButton.styleFrom(foregroundColor: theme.secondaryText),
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
          ],
        ),
      );

  /// Barre de progression fine sous l'en-tête.
  Widget _buildProgress(FlutterFlowTheme theme) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (_page + 1) / _pageCount),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => LinearProgressIndicator(
            value: value,
            minHeight: 4,
            color: theme.primary,
            backgroundColor: theme.alternate,
          ),
        ),
      );

  LinearGradient _gradient(FlutterFlowTheme theme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.primary,
          Color.lerp(theme.primary, theme.tertiary, 0.6)!,
        ],
      );

  /// Illustration (taille adaptée à la hauteur disponible) puis textes ;
  /// défile sur un petit écran.
  Widget _buildStep(FlutterFlowTheme theme, _Step step, int index) =>
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _buildStepContent(theme, step, index,
                (constraints.maxHeight * 0.38).clamp(120.0, 220.0)),
          ),
        ),
      );

  Widget _buildStepContent(
          FlutterFlowTheme theme, _Step step, int index, double hero) =>
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (_, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
              ),
              child: SizedBox(
                width: hero,
                height: hero,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final (ratio, alpha) in [(1.0, 0.06), (0.77, 0.12)])
                      Container(
                        width: hero * ratio,
                        height: hero * ratio,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.primary.withValues(alpha: alpha),
                        ),
                      ),
                    Container(
                      width: hero * 0.53,
                      height: hero * 0.53,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _gradient(theme),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.45),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(step.icon,
                          size: hero * 0.25, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: hero * 0.16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${index + 1} / ${_steps.length}',
                style: theme.labelMedium.copyWith(
                    color: theme.primary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            Text(step.title,
                style:
                    theme.headlineMedium.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                step.text,
                textAlign: TextAlign.center,
                style: theme.bodyLarge
                    .copyWith(color: theme.secondaryText, height: 1.5),
              ),
            ),
          ],
        ),
      );

  Widget _chip(FlutterFlowTheme theme, String label, bool selected,
          ValueChanged<bool> onSelected) =>
      FilterChip(
        label: Text(label),
        selected: selected,
        checkmarkColor: theme.primary,
        selectedColor: theme.primary.withValues(alpha: 0.16),
        backgroundColor: theme.secondaryBackground,
        labelStyle: theme.bodyMedium.copyWith(
          color: selected ? theme.primary : theme.primaryText,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(color: selected ? theme.primary : theme.alternate),
        shape: const StadiumBorder(),
        onSelected: onSelected,
      );

  /// Bloc arrondi d'une rubrique de l'écran Préférences.
  Widget _card(
    FlutterFlowTheme theme, {
    required IconData icon,
    required String title,
    String? hint,
    required Widget child,
  }) =>
      Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.alternate),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.titleMedium
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(hint,
                    style:
                        theme.bodySmall.copyWith(color: theme.secondaryText)),
              ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _buildPreferences(FlutterFlowTheme theme) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vos genres préférés',
                style:
                    theme.headlineMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Choisissez-en quelques-uns pour personnaliser vos recommandations. '
              'Vous pourrez les modifier plus tard.',
              style: theme.bodyMedium
                  .copyWith(color: theme.secondaryText, height: 1.4),
            ),
            _card(
              theme,
              icon: Icons.local_movies_rounded,
              title: 'Genres',
              child: Wrap(
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
            ),
            _card(
              theme,
              icon: Icons.live_tv_rounded,
              title: 'Vos plateformes',
              hint: 'Leurs nouveautés vous seront signalées.',
              child: Wrap(
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
            ),
            _card(
              theme,
              icon: Icons.category_rounded,
              title: 'Types de contenus',
              child: Wrap(
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
            ),
            const SizedBox(height: 16),
            Material(
              color: theme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                secondary: Icon(Icons.notifications_active_outlined,
                    color: theme.primary),
                activeThumbColor: theme.primary,
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

  /// Retour (dès la 2e page) et bouton principal Suivant / Commencer.
  Widget _buildActions(FlutterFlowTheme theme) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Row(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: _page == 0
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primaryText,
                            side: BorderSide(color: theme.alternate),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _saving ? null : _back,
                          child: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: SizedBox(
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _gradient(theme),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      textStyle: theme.titleSmall
                          .copyWith(fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_isLast ? 'Commencer' : 'Suivant'),
                              const SizedBox(width: 8),
                              Icon(
                                  _isLast
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 20),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
