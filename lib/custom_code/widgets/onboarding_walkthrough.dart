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

import '/custom_code/actions/firestore_service.dart';

/// Écran de première utilisation : 4 étapes de présentation puis choix des
/// genres préférés. À la fin, enregistre les choix (completeOnboarding) puis
/// appelle [onFinish] — dans FlutterFlow, branchez-y la navigation vers
/// la HomePage (et le démarrage du Walkthrough FlutterFlow de la HomePage).
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

const _fallbackGenres = [
  'Action',
  'Animation',
  'Comédie',
  'Drame',
  'Fantastique',
  'Horreur',
  'Science-fiction',
  'Thriller',
];

class _OnboardingWalkthroughState extends State<OnboardingWalkthrough> {
  final _pageController = PageController();
  int _page = 0;
  List<String> _genres = _fallbackGenres;
  final Set<String> _selected = {};
  bool _saving = false;

  int get _pageCount => _steps.length + 1;
  bool get _isLast => _page == _pageCount - 1;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await FirestoreService.instance.fetchGenres();
      final names = genres.map((g) => g.name).toList();
      if (mounted && names.isNotEmpty) {
        setState(() => _genres = names);
      }
    } catch (_) {
      // Hors connexion : on garde la liste par défaut.
    }
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final genres = _selected.toList();
    await completeOnboarding(genres);
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
                  _buildGenres(theme),
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

  Widget _buildGenres(FlutterFlowTheme theme) => SingleChildScrollView(
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
              children: _genres
                  .map((g) => FilterChip(
                        label: Text(g),
                        selected: _selected.contains(g),
                        selectedColor: theme.primary.withValues(alpha: 0.2),
                        checkmarkColor: theme.primary,
                        onSelected: (on) => setState(
                            () => on ? _selected.add(g) : _selected.remove(g)),
                      ))
                  .toList(),
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
