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

import 'package:shimmer/shimmer.dart';

/// Squelette de chargement (shimmer) aux couleurs du thème clair / sombre,
/// à afficher pendant le chargement d'un écran (ex. dans un *Conditional
/// Builder* ou à la place du spinner d'une requête Firestore).
///
/// [variant] : `list` (lignes avec vignette, par défaut), `grid` (affiches),
/// `row` (rangée d'affiches horizontale), `detail` (fiche d'un titre).
/// L'effet est figé si l'appareil demande de réduire les animations.
class CineSkeleton extends StatefulWidget {
  const CineSkeleton({
    super.key,
    this.width,
    this.height,
    this.variant,
    this.itemCount,
  });

  final double? width;
  final double? height;
  final String? variant;
  final int? itemCount;

  @override
  State<CineSkeleton> createState() => _CineSkeletonState();
}

const kSkeletonVariants = ['list', 'grid', 'row', 'detail'];

class _CineSkeletonState extends State<CineSkeleton> {
  String get _variant => kSkeletonVariants.contains(widget.variant)
      ? widget.variant!
      : 'list';

  int get _count => (widget.itemCount ?? (_variant == 'grid' ? 6 : 5))
      .clamp(1, 30);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final animate = !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final bone = theme.alternate;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Semantics(
        label: 'Chargement en cours',
        child: ExcludeSemantics(
          child: Shimmer.fromColors(
            enabled: animate,
            baseColor: bone,
            highlightColor: theme.secondaryBackground,
            child: switch (_variant) {
              'grid' => _grid(bone),
              'row' => _row(bone),
              'detail' => _detail(bone),
              _ => _list(bone),
            },
          ),
        ),
      ),
    );
  }

  Widget _list(Color bone) => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _count,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SkeletonBox(width: 44, height: 64, color: bone),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Longueurs variées : plus naturel qu'un bloc uniforme.
                    FractionallySizedBox(
                      widthFactor: i.isEven ? 0.7 : 0.5,
                      child: SkeletonBox(height: 14, color: bone),
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: i.isEven ? 0.45 : 0.6,
                      child: SkeletonBox(height: 10, color: bone),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _grid(Color bone) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.55,
        ),
        itemCount: _count,
        itemBuilder: (_, __) => _poster(bone),
      );

  Widget _row(Color bone) => SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _count,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => SizedBox(width: 120, child: _poster(bone)),
        ),
      );

  Widget _poster(Color bone) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SkeletonBox(color: bone, radius: 12)),
          const SizedBox(height: 8),
          SkeletonBox(height: 12, color: bone),
          const SizedBox(height: 6),
          FractionallySizedBox(
            widthFactor: 0.5,
            child: SkeletonBox(height: 10, color: bone),
          ),
        ],
      );

  Widget _detail(Color bone) => ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          SkeletonBox(height: 220, color: bone, radius: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: SkeletonBox(height: 22, color: bone),
                ),
                const SizedBox(height: 12),
                FractionallySizedBox(
                  widthFactor: 0.35,
                  child: SkeletonBox(height: 12, color: bone),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < _count; i++) ...[
                  FractionallySizedBox(
                    widthFactor: i == _count - 1 ? 0.6 : 1,
                    child: SkeletonBox(height: 12, color: bone),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      );
}

/// Bloc gris arrondi d'un squelette (à mettre sous un `Shimmer`).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    required this.color,
    this.radius = 6,
  });

  final double? width;
  final double? height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
