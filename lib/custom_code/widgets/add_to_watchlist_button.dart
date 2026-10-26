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

import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/firestore_service.dart';

/// Bouton « Ajouter à une liste » de la fiche d'un titre (membre 1).
/// Ouvre une feuille avec les listes du membre connecté ; on peut aussi
/// créer une liste et y ajouter le titre en une fois.
class AddToWatchlistButton extends StatefulWidget {
  const AddToWatchlistButton({
    super.key,
    this.width,
    this.height,
    required this.mediaId,
  });

  final double? width;
  final double? height;
  final String mediaId;

  @override
  State<AddToWatchlistButton> createState() => _AddToWatchlistButtonState();
}

class _AddToWatchlistButtonState extends State<AddToWatchlistButton> {
  void _open() {
    if (FirestoreService.instance.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connectez-vous pour gérer vos listes.'),
      ));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WatchlistSheet(mediaId: widget.mediaId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.primary,
          side: BorderSide(color: theme.primary),
        ),
        onPressed: _open,
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text('Ajouter à une liste'),
      ),
    );
  }
}

class _WatchlistSheet extends StatefulWidget {
  const _WatchlistSheet({required this.mediaId});

  final String mediaId;

  @override
  State<_WatchlistSheet> createState() => _WatchlistSheetState();
}

class _WatchlistSheetState extends State<_WatchlistSheet> {
  final _service = FirestoreService.instance;
  final _name = TextEditingController();
  List<Watchlist> _lists = const [];
  Set<String> _containing = const {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lists = await _service.fetchMyWatchlists();
      final containing = await _service.watchlistIdsWithMedia(widget.mediaId);
      if (mounted) {
        setState(() {
          _lists = lists;
          _containing = containing;
          _loading = false;
        });
      }
    } on CineFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _loading = false;
        });
      }
    }
  }

  /// Ferme la feuille et affiche [message] sur la page.
  void _done(String message) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add(Watchlist list) async {
    if (_containing.contains(list.id)) {
      _done('Ce titre est déjà dans « ${list.name} ».');
      return;
    }
    setState(() => _busy = true);
    final error = await addToWatchlist(list.id, widget.mediaId);
    if (!mounted) {
      return;
    }
    if (error.isEmpty) {
      _done('Ajouté à « ${list.name} ».');
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _createAndAdd() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final list = await _service.createWatchlist(_name.text);
      await _service.addMediaToWatchlist(list.id, widget.mediaId);
      if (mounted) {
        _done('Liste « ${list.name} » créée avec ce titre.');
      }
    } on CineFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ajouter à une liste', style: theme.titleLarge),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_lists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Vous n\'avez pas encore de liste. Créez-en une :',
                  style: theme.bodyMedium.copyWith(color: theme.secondaryText)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final list in _lists)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: !_busy,
                      leading: Icon(Icons.playlist_play_rounded,
                          color: theme.primary),
                      title: Text(list.name),
                      trailing: _containing.contains(list.id)
                          ? Icon(Icons.check_circle_rounded,
                              color: theme.success)
                          : const Icon(Icons.add_rounded),
                      onTap: () => _add(list),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _createAndAdd(),
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle liste',
                    hintText: 'Ex. : À voir ce week-end',
                    prefixIcon: Icon(Icons.playlist_add_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _createAndAdd,
                child: const Text('Créer'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: theme.bodySmall.copyWith(color: theme.error)),
          ],
        ],
      ),
    );
  }
}
