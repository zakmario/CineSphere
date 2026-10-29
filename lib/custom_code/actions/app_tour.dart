// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

import '/custom_code/actions/complete_onboarding.dart';

/// Guide de l'application (visite guidée, cahier des charges section 6.1).
///
/// Action FlutterFlow : lance le guide tout de suite, par exemple depuis un
/// bouton « Guide de l'application » des Paramètres. Renvoie vrai si le
/// guide a été affiché. Après l'écran de présentation, l'OnboardingWalkthrough
/// le lance tout seul (une seule fois par appareil).
Future<bool> startAppTour() => AppTour.start();

/// Ce que le guide dit de chaque onglet de la barre de navigation, retrouvé
/// par son libellé (un onglet inconnu reçoit un texte générique).
class TourTab {
  const TourTab(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

const kTourTabs = <String, TourTab>{
  'Accueil': TourTab(
      Icons.home_rounded,
      'Accueil',
      'Tendances, sorties à venir et titres les mieux notés, choisis selon '
          'vos genres préférés.'),
  'Catalogue': TourTab(
      Icons.manage_search_rounded,
      'Catalogue et recherche',
      'Cherchez un film ou une série par son titre, puis filtrez par genre, '
          'plateforme ou année.'),
  'Calendrier': TourTab(
      Icons.calendar_month_rounded,
      'Calendrier des sorties',
      'Repérez les prochaines sorties jour par jour et programmez un rappel '
          'en un geste.'),
  'Favoris': TourTab(
      Icons.favorite_rounded,
      'Vos favoris',
      'Tous les titres enregistrés avec le cœur, et vos listes '
          'personnalisées.'),
  'Avis': TourTab(
      Icons.rate_review_rounded,
      'Avis',
      'Notez les films que vous avez vus et découvrez l’avis des autres '
          'membres.'),
  'Actualités': TourTab(Icons.newspaper_rounded, 'Actualités',
      'Les dernières nouvelles du cinéma et des séries, chaque jour.'),
  'Paramètres': TourTab(
      Icons.settings_rounded,
      'Paramètres',
      'Activez les rappels de sortie, gérez votre compte et revoyez la '
          'présentation quand vous voulez.'),
};

/// Une étape : [target] est la zone mise en lumière (null : carte centrée).
class TourStep {
  const TourStep({
    required this.icon,
    required this.title,
    required this.text,
    this.target,
  });

  final IconData icon;
  final String title;
  final String text;
  final Rect? target;
}

/// Étapes du guide pour une barre de navigation : accueil, un onglet par
/// libellé, conclusion.
List<TourStep> buildTourSteps(Rect bar, List<String> labels) {
  final width = labels.isEmpty ? 0.0 : bar.width / labels.length;
  return [
    const TourStep(
      icon: Icons.movie_filter_rounded,
      title: 'Bienvenue sur CinéSphère',
      text: 'Faisons le tour de l’application en moins d’une minute : '
          'nous vous montrons où trouver l’essentiel.',
    ),
    for (final (i, label) in labels.indexed)
      () {
        final tab = kTourTabs[label] ??
            TourTab(Icons.touch_app_rounded, label,
                'Touchez « $label » pour ouvrir cette rubrique.');
        return TourStep(
          icon: tab.icon,
          title: tab.title,
          text: tab.text,
          target:
              Rect.fromLTWH(bar.left + i * width, bar.top, width, bar.height),
        );
      }(),
    const TourStep(
      icon: Icons.celebration_rounded,
      title: 'Vous êtes prêt !',
      text: 'Explorez le catalogue, ajoutez vos favoris et activez les '
          'rappels pour ne manquer aucune sortie.',
    ),
  ];
}

/// Affiche le guide par-dessus l'application (Overlay du navigateur de
/// FlutterFlow), en mettant en lumière les onglets de la barre de
/// navigation.
class AppTour {
  AppTour._();

  static OverlayEntry? _entry;

  /// Nombre d'images attendues au plus pour voir apparaître la barre de
  /// navigation (~3 s), et d'images où sa position doit rester stable.
  static const int maxFrames = 180;
  static const int stableFrames = 3;

  static bool get isShowing => _entry != null;

  /// Lance le guide si l'onboarding vient d'être fait et que le guide n'a
  /// jamais été montré sur cet appareil.
  static Future<bool> startAfterOnboarding() async {
    if (!await OnboardingService.instance.shouldStartHomeTour()) {
      return false;
    }
    return start();
  }

  /// Attend la barre de navigation puis affiche le guide. Faux si elle
  /// n'apparaît pas (page sans barre) ou si le guide est déjà affiché.
  static Future<bool> start() async {
    if (isShowing) {
      return false;
    }
    final bar = await _waitForNavBar();
    final overlay = appNavigatorKey.currentState?.overlay;
    if (bar == null || overlay == null || isShowing) {
      return false;
    }
    final steps = buildTourSteps(bar.rect, bar.labels);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => AppTourView(
        steps: steps,
        onClose: () {
          entry.remove();
          _entry = null;
          unawaited(OnboardingService.instance.markHomeTourDone());
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    return true;
  }

  static Future<_NavBar?> _waitForNavBar() async {
    _NavBar? last;
    var stable = 0;
    for (var frame = 0; frame < maxFrames; frame++) {
      if (appNavigatorKey.currentContext == null) {
        return null;
      }
      final bar = _findNavBar();
      if (bar != null && bar.rect == last?.rect) {
        if (++stable >= stableFrames) {
          return bar;
        }
      } else {
        stable = 0;
      }
      last = bar;
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    return null;
  }

  /// BottomNavigationBar affichée (celle de NavBarPage dans FlutterFlow).
  static _NavBar? _findNavBar() {
    final root = appNavigatorKey.currentContext;
    if (root == null) {
      return null;
    }
    _NavBar? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      final widget = element.widget;
      if (widget is BottomNavigationBar) {
        final box = element.renderObject;
        if (box is RenderBox && box.hasSize && box.attached) {
          final origin = box.localToGlobal(Offset.zero);
          // Sans la marge du bas (barre gestuelle) : la zone des icônes.
          final inset = MediaQuery.maybeOf(element)?.padding.bottom ?? 0;
          final height = math.max(box.size.height - inset, 1.0);
          found = _NavBar(
            Rect.fromLTWH(origin.dx, origin.dy, box.size.width, height),
            [for (final item in widget.items) item.label ?? ''],
          );
        }
        return;
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return found;
  }
}

class _NavBar {
  const _NavBar(this.rect, this.labels);
  final Rect rect;
  final List<String> labels;
}

/// Vue du guide : voile sombre percé autour de la zone présentée, carte
/// d'explication avec progression, Passer / Retour / Suivant.
class AppTourView extends StatefulWidget {
  const AppTourView({super.key, required this.steps, required this.onClose});

  final List<TourStep> steps;
  final VoidCallback onClose;

  @override
  State<AppTourView> createState() => _AppTourViewState();
}

class _AppTourViewState extends State<AppTourView>
    with TickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  TourStep get _step => widget.steps[_index];
  bool get _isFirst => _index == 0;
  bool get _isLast => _index == widget.steps.length - 1;

  @override
  void dispose() {
    _pulse.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0) {
      return;
    }
    if (index >= widget.steps.length) {
      _close();
      return;
    }
    setState(() => _index = index);
  }

  Future<void> _close() async {
    await _fade.reverse();
    widget.onClose();
  }

  /// Zone mise en lumière, un peu agrandie ; sans cible, un point au centre
  /// (le voile couvre tout l'écran).
  Rect _hole(Size size) {
    final target = _step.target;
    if (target == null) {
      return Rect.fromCenter(
          center: size.center(Offset.zero), width: 0, height: 0);
    }
    return target.deflate(4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final hole = _hole(size);

    return FadeTransition(
      opacity: _fade,
      child: Material(
        type: MaterialType.transparency,
        child: TweenAnimationBuilder<Rect?>(
          tween: RectTween(end: hole),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, rect, _) {
            final current = rect ?? hole;
            return Stack(
              children: [
                // Le voile absorbe les touchers ; la zone éclairée fait
                // avancer le guide.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      if (_step.target != null &&
                          current.contains(details.globalPosition)) {
                        _go(_index + 1);
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => CustomPaint(
                        painter: _SpotlightPainter(
                          hole: current,
                          pulse: _pulse.value,
                          color: theme.primary,
                          visible: _step.target != null,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildCard(theme, size, current),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(FlutterFlowTheme theme, Size size, Rect hole) {
    final padding = MediaQuery.paddingOf(context);
    final width = math.min(size.width - 32, 400.0);
    final left = (size.width - width) / 2;
    final card = _TourCard(
      key: ValueKey(_index),
      step: _step,
      index: _index,
      count: widget.steps.length,
      isFirst: _isFirst,
      isLast: _isLast,
      onSkip: _close,
      onBack: () => _go(_index - 1),
      onNext: () => _go(_index + 1),
    );
    final switcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: card,
    );

    if (_step.target == null) {
      return Positioned(
        left: left,
        width: width,
        top: 0,
        bottom: 0,
        child: Center(child: switcher),
      );
    }
    // Carte au-dessus de la zone si elle est dans la moitié basse.
    final above = hole.center.dy > size.height / 2;
    return Positioned(
      left: left,
      width: width,
      top: above ? null : hole.bottom + 14,
      bottom: above ? size.height - hole.top + 14 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(
              above
                  ? hole.top - padding.top - 28
                  : size.height - hole.bottom - padding.bottom - 28,
              160),
        ),
        child: Align(
          alignment: above ? Alignment.bottomCenter : Alignment.topCenter,
          child: SingleChildScrollView(reverse: above, child: switcher),
        ),
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.isFirst,
    required this.isLast,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  final TourStep step;
  final int index;
  final int count;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final progress = (index + 1) / count;
    final accent = theme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, Color.lerp(accent, theme.tertiary, 0.6)!],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(step.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'ÉTAPE ${index + 1} SUR $count',
                  style: theme.labelSmall.copyWith(
                    color: accent,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isLast)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.secondaryText,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Passer'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            step.title,
            style: theme.titleLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            step.text,
            style: theme.bodyMedium
                .copyWith(color: theme.secondaryText, height: 1.45),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: accent,
                backgroundColor: theme.alternate,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!isFirst && !isLast)
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Retour'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryText,
                    side: BorderSide(color: theme.alternate),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onNext,
                iconAlignment: IconAlignment.end,
                icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 18),
                label: Text(isFirst
                    ? 'Commencer la visite'
                    : isLast
                        ? 'C’est parti'
                        : 'Suivant'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Voile sombre avec un trou arrondi et un halo qui pulse autour.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.hole,
    required this.pulse,
    required this.color,
    required this.visible,
  });

  final Rect hole;
  final double pulse;
  final Color color;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(math.min(16, hole.shortestSide / 2));
    final rrect = RRect.fromRectAndRadius(hole, radius);
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rrect),
    );
    canvas.drawPath(
        scrim, Paint()..color = Colors.black.withValues(alpha: 0.74));
    if (!visible || hole.isEmpty) {
      return;
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    final grow = 4 + 10 * pulse;
    canvas.drawRRect(
      rrect.inflate(grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - pulse) * 0.6),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole ||
      old.pulse != pulse ||
      old.color != color ||
      old.visible != visible;
}
