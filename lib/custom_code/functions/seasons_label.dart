import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Type;
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/auth/firebase_auth/auth_util.dart';

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
