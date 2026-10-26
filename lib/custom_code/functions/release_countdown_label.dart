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
import '/backend/supabase/supabase.dart';
import '/auth/firebase_auth/auth_util.dart';

/// Libellé de compte à rebours : "Aujourd'hui", "Demain", "Dans 5 jours",
/// "Sorti".
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
