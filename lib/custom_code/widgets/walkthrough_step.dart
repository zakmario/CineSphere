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

/// Bulle d'une étape de la visite guidée de la HomePage (Walkthroughs
/// FlutterFlow) : « Étape 2 sur 5 », titre, explication, boutons Passer /
/// Suivant (Terminer à la dernière étape). À mettre dans le component
/// affiché par chaque étape du Walkthrough.
class WalkthroughStep extends StatefulWidget {
  const WalkthroughStep({
    super.key,
    this.width,
    this.height,
    required this.title,
    required this.text,
    this.stepNumber,
    this.stepCount,
    this.onNext,
    this.onSkip,
  });

  final double? width;
  final double? height;
  final String title;
  final String text;

  /// Numéro de l'étape (à partir de 1) et nombre d'étapes.
  final int? stepNumber;
  final int? stepCount;

  /// Sans action, le bouton n'est pas affiché (un tap sur le fond passe
  /// alors à l'étape suivante).
  final Future Function()? onNext;
  final Future Function()? onSkip;

  @override
  State<WalkthroughStep> createState() => _WalkthroughStepState();
}

class _WalkthroughStepState extends State<WalkthroughStep> {
  int? get _number => widget.stepNumber;
  int? get _count => widget.stepCount;

  bool get _isLast => _number != null && _count != null && _number! >= _count!;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final hasProgress = _number != null && _count != null && _count! > 0;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: theme.secondaryBackground,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasProgress)
                  Row(
                    children: [
                      Text('Étape $_number sur $_count',
                          style: theme.labelSmall
                              .copyWith(color: theme.secondaryText)),
                      const SizedBox(width: 8),
                      for (var i = 1; i <= _count!; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 4),
                          width: i == _number ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                i <= _number! ? theme.primary : theme.alternate,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                if (hasProgress) const SizedBox(height: 8),
                Text(widget.title, style: theme.titleMedium),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(widget.text,
                      style: theme.bodyMedium
                          .copyWith(color: theme.secondaryText)),
                ),
                if (widget.onNext != null || widget.onSkip != null)
                  Row(
                    children: [
                      if (widget.onSkip != null && !_isLast)
                        TextButton(
                          onPressed: () => widget.onSkip!(),
                          child: const Text('Passer'),
                        ),
                      const Spacer(),
                      if (widget.onNext != null)
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: theme.primary),
                          onPressed: () => widget.onNext!(),
                          child: Text(_isLast ? 'Terminer' : 'Suivant'),
                        ),
                    ],
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
