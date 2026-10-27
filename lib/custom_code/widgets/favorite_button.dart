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

/// Bouton cœur relié à `users/{uid}/favorites` de Firestore.
/// Charge son état tout seul, change immédiatement au toucher et appelle
/// [onChanged] avec le nouvel état (puis l'ancien si l'écriture échoue).
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    this.width,
    this.height,
    required this.mediaId,
    this.iconSize,
    this.onChanged,
  });

  final double? width;
  final double? height;
  final String mediaId;
  final double? iconSize;
  final Future Function(bool isFavorite)? onChanged;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _isFavorite = false;
  bool _busy = true;
  StreamSubscription<MediaChange>? _changes;

  @override
  void initState() {
    super.initState();
    // Même titre ajouté ou retiré ailleurs (fiche, carte, autre bouton).
    _changes = CineFirebaseService.instance.mediaChanges.listen((change) {
      if (mounted &&
          change.flag == MediaFlag.favorite &&
          change.mediaId == widget.mediaId &&
          change.value != _isFavorite) {
        setState(() => _isFavorite = change.value);
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
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
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
        _isFavorite = false;
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final value = await CineFirebaseService.instance.isFavorite(widget.mediaId);
      if (mounted) {
        setState(() => _isFavorite = value);
      }
    } catch (_) {
      // On laisse le cœur vide en cas d'erreur réseau.
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

  /// Mise à jour optimiste (section 6.7) : le cœur change tout de suite, puis
  /// revient en arrière si Firestore refuse. Sans réseau, Firestore garde
  /// l'écriture en file et l'envoie au retour de la connexion.
  Future<void> _toggle() async {
    final service = CineFirebaseService.instance;
    if (service.currentUserId == null) {
      _snack('Connectez-vous pour gérer vos favoris.');
      return;
    }
    final value = !_isFavorite;
    setState(() => _isFavorite = value);
    _snack(value ? 'Ajouté aux favoris' : 'Retiré des favoris');
    final onChanged = widget.onChanged;
    if (onChanged != null) {
      unawaited(onChanged(value));
    }
    try {
      await service.setFavorite(widget.mediaId, value);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isFavorite = !value);
      _snack(error is CineFailure
          ? error.message
          : 'Impossible de modifier vos favoris.');
      if (onChanged != null) {
        unawaited(onChanged(!value));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final size = widget.iconSize ?? 28;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: _busy
            ? SizedBox(
                width: size * 0.7,
                height: size * 0.7,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: _isFavorite
                    ? 'Retirer des favoris'
                    : 'Ajouter aux favoris',
                iconSize: size,
                onPressed: _toggle,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(_isFavorite),
                    color: _isFavorite ? theme.error : theme.secondaryText,
                  ),
                ),
              ),
      ),
    );
  }
}
