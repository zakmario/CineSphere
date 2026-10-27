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

import '/custom_code/actions/firebase_service.dart';

/// Bouton « Marquer comme vu » de la fiche d'un titre (membre 1), relié à
/// `users/{uid}/watched`. Charge son état tout seul, change immédiatement
/// au toucher et appelle [onChanged] ; le titre apparaît dans l'onglet Vus.
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
  StreamSubscription<MediaChange>? _changes;

  @override
  void initState() {
    super.initState();
    // Même titre marqué ou retiré ailleurs.
    _changes = CineFirebaseService.instance.mediaChanges.listen((change) {
      if (mounted &&
          change.flag == MediaFlag.watched &&
          change.mediaId == widget.mediaId &&
          change.value != _isWatched) {
        setState(() => _isWatched = change.value);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
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

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 2),
    ));

  /// Mise à jour optimiste, comme FavoriteButton.
  Future<void> _toggle() async {
    final service = CineFirebaseService.instance;
    if (service.currentUserId == null) {
      _snack('Connectez-vous pour marquer un titre comme vu.');
      return;
    }
    final value = !_isWatched;
    setState(() => _isWatched = value);
    _snack(value ? 'Ajouté à vos titres vus' : 'Retiré des vus');
    final onChanged = widget.onChanged;
    if (onChanged != null) {
      unawaited(onChanged(value));
    }
    try {
      await service.setWatched(widget.mediaId, value);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isWatched = !value);
      _snack(error is CineFailure
          ? error.message
          : 'Impossible de modifier vos titres vus.');
      if (onChanged != null) {
        unawaited(onChanged(!value));
      }
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
