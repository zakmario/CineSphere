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

/// Nombre de jours calendaires entre aujourd'hui et [date] (négatif si la
/// date est passée).
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
