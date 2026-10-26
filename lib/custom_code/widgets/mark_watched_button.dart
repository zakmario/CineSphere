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

import '/custom_code/actions/firebase_service.dart';

/// Bouton « Marquer comme vu » de la fiche d'un titre (membre 1), relié à
/// la table `watched`. Charge son état tout seul et appelle [onChanged]
/// après chaque changement ; le titre apparaît alors dans l'onglet Vus.
class MarkWatchedButton extends StatefulWidget {
  const MarkWatchedButton({
    super.key,
    this.width,
    this.height,
    required this.mediaId,
    this.onChanged,
  });

  final double? width;
  final double? height;
  final String mediaId;
  final Future Function(bool isWatched)? onChanged;

  @override
  State<MarkWatchedButton> createState() => _MarkWatchedButtonState();
}

class _MarkWatchedButtonState extends State<MarkWatchedButton> {
  bool _isWatched = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MarkWatchedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    if (CineFirebaseService.instance.currentUserId == null) {
      setState(() {
        _isWatched = false;
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final value = await CineFirebaseService.instance.isWatched(widget.mediaId);
      if (mounted) {
        setState(() => _isWatched = value);
      }
    } catch (_) {
      // On affiche « non vu » en cas d'erreur réseau.
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final value = await toggleWatched(widget.mediaId);
      if (!mounted) {
        return;
      }
      setState(() => _isWatched = value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? 'Ajouté à vos titres vus' : 'Retiré des vus'),
        duration: const Duration(seconds: 2),
      ));
      await widget.onChanged?.call(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ));
      }
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final icon = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_isWatched
            ? Icons.check_circle_rounded
            : Icons.visibility_outlined);
    final label = Text(_isWatched ? 'Vu' : 'Marquer comme vu');
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _isWatched
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.success,
                foregroundColor: Colors.white,
              ),
              onPressed: _busy ? null : _toggle,
              icon: icon,
              label: label,
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.primary,
                side: BorderSide(color: theme.primary),
              ),
              onPressed: _busy ? null : _toggle,
              icon: icon,
              label: label,
            ),
    );
  }
}
