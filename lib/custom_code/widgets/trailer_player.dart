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

import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Lecteur de bande-annonce YouTube intégré à l'application (membre 1) :
/// la vidéo se lit dans la page, sans ouvrir YouTube. Utilise directement
/// youtube_player_iframe, le paquet du lecteur natif de FlutterFlow (page
/// BandeAnnonce) : l'analyseur de code custom de FlutterFlow ne voit pas le
/// fichier généré flutter_flow_youtube_player.dart. [trailerUrl] est une
/// adresse YouTube (`watch?v=`, `youtu.be/`, `embed/`).
class TrailerPlayer extends StatefulWidget {
  const TrailerPlayer({
    super.key,
    this.width,
    this.height,
    required this.trailerUrl,
    this.autoPlay = true,
  });

  final double? width;
  final double? height;
  final String trailerUrl;
  final bool autoPlay;

  @override
  State<TrailerPlayer> createState() => _TrailerPlayerState();
}

/// Ouvre la bande-annonce dans une fenêtre de l'application.
Future<void> showTrailerDialog(BuildContext context, String trailerUrl,
    {String? title}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final theme = FlutterFlowTheme.of(context);
      return Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title == null || title.isEmpty
                            ? 'Bande-annonce'
                            : 'Bande-annonce · $title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall.override(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              TrailerPlayer(trailerUrl: trailerUrl),
            ],
          ),
        ),
      );
    },
  );
}

/// Identifiant de la vidéo dans une adresse YouTube, ou null.
String? youtubeVideoId(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.host.contains('youtu')) {
    return null;
  }
  final id = uri.host.contains('youtu.be')
      ? (uri.pathSegments.isEmpty ? null : uri.pathSegments.first)
      : uri.queryParameters['v'] ??
          (uri.pathSegments.length >= 2 &&
                  const ['embed', 'shorts', 'live']
                      .contains(uri.pathSegments[0])
              ? uri.pathSegments[1]
              : null);
  return id != null && RegExp(r'^[\w-]{11}$').hasMatch(id) ? id : null;
}

class _TrailerPlayerState extends State<TrailerPlayer> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TrailerPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailerUrl != widget.trailerUrl) {
      _controller?.close();
      _load();
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  /// Mêmes réglages que le lecteur FlutterFlow (vidéos suggérées limitées à
  /// la chaîne, domaine youtube-nocookie).
  void _load() {
    final id = youtubeVideoId(widget.trailerUrl);
    _controller = id == null
        ? null
        : YoutubePlayerController.fromVideoId(
            videoId: id,
            autoPlay: widget.autoPlay,
            params: const YoutubePlayerParams(
              origin: 'https://www.youtube-nocookie.com',
              showFullscreenButton: true,
              strictRelatedVideos: true,
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final player = controller == null
        ? AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(
              child: Text('Bande-annonce indisponible.',
                  style: FlutterFlowTheme.of(context)
                      .bodyMedium
                      .override(color: Colors.white70)),
            ),
          )
        : YoutubePlayer(
            controller: controller,
            enableFullScreenOnVerticalDrag: false,
          );
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(color: Colors.black, child: player),
    );
  }
}
