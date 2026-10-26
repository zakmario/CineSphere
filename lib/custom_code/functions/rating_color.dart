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

/// Couleur associée à une note : vert (>= 7.5), orange (>= 5), rouge, gris si
/// absente.
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
