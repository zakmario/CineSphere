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

import 'package:cached_network_image/cached_network_image.dart';

/// Carte réutilisable d'un film ou d'une série : affiche arrondie avec
/// ombre douce, badge de type, note sur pastille sombre, titre et année
/// (ou compte à rebours si à venir). Légère réduction au toucher.
class MediaCard extends StatefulWidget {
  const MediaCard({
    super.key,
    this.width,
    this.height,
    required this.title,
    this.posterUrl,
    this.mediaType,
    this.rating,
    this.releaseDate,
    this.onTap,
  });

  final double? width;
  final double? height;
  final String title;
  final String? posterUrl;
  final String? mediaType;
  final double? rating;
  final DateTime? releaseDate;
  final Future Function()? onTap;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  static const _radius = 16.0;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap != null && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final posterUrl = widget.posterUrl;
    final rating = widget.rating;
    final releaseDate = widget.releaseDate;
    final onTap = widget.onTap;

    final theme = FlutterFlowTheme.of(context);
    final upcoming = releaseDate != null && daysUntil(releaseDate) > 0;
    final subtitle = upcoming
        ? releaseCountdownLabel(releaseDate)
        : (releaseDate?.year.toString() ?? '');

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: onTap == null ? null : () => onTap(),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_radius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        posterUrl == null || posterUrl.isEmpty
                            ? _placeholder(theme)
                            : CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                fadeInDuration:
                                    const Duration(milliseconds: 250),
                                placeholder: (_, __) => _placeholder(theme),
                                errorWidget: (_, __, ___) =>
                                    _placeholder(theme),
                              ),
                        // Dégradé en haut pour la lisibilité des badges.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.center,
                              colors: [Color(0x66000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _badge(
                            mediaTypeLabel(widget.mediaType),
                            Colors.white,
                            Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _badge(
                            '★ ${ratingLabel(rating)}',
                            ratingColor(rating),
                            Colors.black.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: theme.bodySmall.copyWith(
                      color: upcoming ? theme.primary : theme.secondaryText,
                      fontWeight: upcoming ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(FlutterFlowTheme theme) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.alternate, theme.accent4],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.movie_outlined, color: theme.secondaryText, size: 36),
      );

  Widget _badge(String text, Color textColor, Color background) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      );
}
