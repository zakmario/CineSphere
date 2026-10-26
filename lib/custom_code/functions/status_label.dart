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
import '/auth/firebase_auth/auth_util.dart';

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
