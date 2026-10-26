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

/// Bouton cœur relié à la collection `favorites` de Firestore.
/// Charge son état tout seul et appelle [onChanged] après chaque changement.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final value = await toggleFavorite(widget.mediaId);
      if (!mounted) {
        return;
      }
      setState(() => _isFavorite = value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(value ? 'Ajouté aux favoris' : 'Retiré des favoris'),
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
