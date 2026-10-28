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

/// Durée d'apparition d'un élément.
const Duration kFadeSlideDuration = Duration(milliseconds: 320);

/// Décalage entre deux éléments d'une liste (effet « cascade »).
const Duration kFadeSlideStagger = Duration(milliseconds: 45);

/// Au-delà, les éléments apparaissent sans attendre les précédents.
const int kFadeSlideMaxStagger = 8;

/// Fait apparaître [child] en fondu avec un léger glissement vers le haut,
/// décalé selon [index] dans une liste. Rien n'est animé si l'appareil
/// demande de réduire les animations ou si [enabled] est faux (ex. éléments
/// chargés plus tard au scroll).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    this.width,
    this.height,
    required this.child,
    this.index,
    this.enabled,
  });

  final double? width;
  final double? height;
  final Widget child;
  final int? index;
  final bool? enabled;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    // Le délai fait partie de l'animation (Interval) : pas de Timer.
    final delay =
        kFadeSlideStagger * (widget.index ?? 0).clamp(0, kFadeSlideMaxStagger);
    final total = delay + kFadeSlideDuration;
    _controller = AnimationController(vsync: this, duration: total);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1,
          curve: Curves.easeOutCubic),
    );
    _opacity = curve;
    _offset = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) {
      return;
    }
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || widget.enabled == false) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(position: _offset, child: widget.child),
        ),
      );
}

/// Passage animé entre deux états d'un écran (chargement, contenu, erreur,
/// vide) : fondu enchaîné, sans animation si l'appareil la refuse.
/// [stateKey] change quand l'état change.
Widget cineStateSwitcher(
        BuildContext context, Object stateKey, Widget child) =>
    AnimatedSwitcher(
      duration: (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
