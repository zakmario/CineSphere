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
import '/auth/firebase_auth/auth_util.dart';

/// Vrai si la sortie a lieu aujourd'hui ou dans les [withinDays] prochains
/// jours.
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
