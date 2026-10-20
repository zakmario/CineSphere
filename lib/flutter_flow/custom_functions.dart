import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';

/// Convertit une durée en minutes en texte lisible : 148 -> "2 h 28 min".
String formatRuntime(int? minutes) {
  if (minutes == null || minutes <= 0) {
    return '';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) {
    return '$rest min';
  }
  if (rest == 0) {
    return '$hours h';
  }
  return '$hours h ${rest.toString().padLeft(2, '0')} min';
}

/// Formate une date en français : "16 juillet 2010".
String formatReleaseDate(DateTime? date) {
  if (date == null) {
    return 'Date inconnue';
  }
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Nombre de jours calendaires entre aujourd'hui et [date]
/// (négatif si la date est passée).
int daysUntil(DateTime? date) {
  if (date == null) {
    return 0;
  }
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  final local = date.toLocal();
  final target = DateTime.utc(local.year, local.month, local.day);
  return target.difference(today).inDays;
}

/// Vrai si la sortie a lieu aujourd'hui ou dans les [withinDays] prochains jours.
bool isReleaseSoon(
  DateTime? date,
  int withinDays,
) {
  if (date == null) {
    return false;
  }
  final days = daysUntil(date);
  return days >= 0 && days <= withinDays;
}

/// Libellé de compte à rebours : "Aujourd'hui", "Demain", "Dans 5 jours", "Sorti".
String releaseCountdownLabel(DateTime? date) {
  if (date == null) {
    return 'Date à venir';
  }
  final days = daysUntil(date);
  if (days < 0) {
    return 'Sorti';
  }
  if (days == 0) {
    return "Aujourd'hui";
  }
  if (days == 1) {
    return 'Demain';
  }
  return 'Dans $days jours';
}

/// "movie" -> "Film", "series" -> "Série".
String mediaTypeLabel(String? mediaType) {
  switch (mediaType) {
    case 'movie':
      return 'Film';
    case 'series':
      return 'Série';
    default:
      return 'Tous';
  }
}

/// Statut du contenu en français.
String statusLabel(String? status) {
  switch (status) {
    case 'released':
      return 'Disponible';
    case 'ongoing':
      return 'En cours';
    case 'upcoming':
      return 'À venir';
    case 'ended':
      return 'Terminée';
    default:
      return '';
  }
}

/// "5 saisons • 62 épisodes".
String seasonsLabel(
  int? seasons,
  int? episodes,
) {
  final parts = <String>[];
  if (seasons != null && seasons > 0) {
    parts.add('$seasons saison${seasons > 1 ? 's' : ''}');
  }
  if (episodes != null && episodes > 0) {
    parts.add('$episodes épisode${episodes > 1 ? 's' : ''}');
  }
  return parts.join(' • ');
}

/// Note sur 10 affichée avec une décimale, ou "—" si pas encore notée.
String ratingLabel(double? rating) {
  if (rating == null || rating <= 0) {
    return '—';
  }
  return rating.toStringAsFixed(1);
}

/// Couleur associée à une note : vert (>= 7.5), orange (>= 5), rouge, gris si absente.
Color ratingColor(double? rating) {
  if (rating == null || rating <= 0) {
    return const Color(0xFF9E9E9E);
  }
  if (rating >= 7.5) {
    return const Color(0xFF2E7D32);
  }
  if (rating >= 5) {
    return const Color(0xFFF9A825);
  }
  return const Color(0xFFC62828);
}

/// Identifiant de notification stable (entier 31 bits) dérivé d'une chaîne,
/// ex. l'id d'un release_event. String.hashCode n'est pas garanti stable
/// entre deux lancements, d'où ce hash FNV-1a.
int notificationIdFromString(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
