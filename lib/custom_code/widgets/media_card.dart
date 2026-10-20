// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cached_network_image/cached_network_image.dart';

/// Carte réutilisable d'un film ou d'une série : affiche, badge de type,
/// note colorée, titre et année (ou compte à rebours si à venir).
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
  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final posterUrl = widget.posterUrl;
    final mediaType = widget.mediaType;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null ? null : () => onTap(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: posterUrl == null || posterUrl.isEmpty
                        ? _placeholder(theme)
                        : CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _placeholder(theme),
                            errorWidget: (_, __, ___) => _placeholder(theme),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _badge(
                      mediaTypeLabel(mediaType),
                      Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _badge(
                      '★ ${ratingLabel(rating)}',
                      ratingColor(rating),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: theme.bodySmall.copyWith(
                  color: upcoming ? theme.primary : theme.secondaryText,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(FlutterFlowTheme theme) => Container(
        color: theme.alternate,
        alignment: Alignment.center,
        child: Icon(Icons.movie_outlined, color: theme.secondaryText, size: 36),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
