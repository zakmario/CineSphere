import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'dart:async';
import 'detail_liste_widget.dart' show DetailListeWidget;
import 'package:cloud_firestore/cloud_firestore.dart' hide Type;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

class DetailListeModel extends FlutterFlowModel<DetailListeWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for ListNameField widget.
  FocusNode? listNameFieldFocusNode;
  TextEditingController? listNameFieldTextController;
  String? Function(BuildContext, String?)? listNameFieldTextControllerValidator;
  // Stores action output result for [Custom Action - renameWatchlist] action in RenameButton widget.
  String? renommage;
  Completer<WatchlistsRecord>? documentRequestCompleter;
  // Stores action output result for [Custom Action - removeWatchlistItem] action in Container widget.
  String? retrait;
  Completer<List<ItemsRecord>>? firestoreRequestCompleter;
  // Stores action output result for [Custom Action - deleteWatchlist] action in DeleteListButton widget.
  String? suppression;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    listNameFieldFocusNode?.dispose();
    listNameFieldTextController?.dispose();
  }

  /// Additional helper methods.
  Future waitForDocumentRequestCompleted({
    double minWait = 0,
    double maxWait = double.infinity,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      await Future.delayed(Duration(milliseconds: 50));
      final timeElapsed = stopwatch.elapsedMilliseconds;
      final requestComplete = documentRequestCompleter?.isCompleted ?? false;
      if (timeElapsed > maxWait || (requestComplete && timeElapsed > minWait)) {
        break;
      }
    }
  }

  Future waitForFirestoreRequestCompleted({
    double minWait = 0,
    double maxWait = double.infinity,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      await Future.delayed(Duration(milliseconds: 50));
      final timeElapsed = stopwatch.elapsedMilliseconds;
      final requestComplete = firestoreRequestCompleter?.isCompleted ?? false;
      if (timeElapsed > maxWait || (requestComplete && timeElapsed > minWait)) {
        break;
      }
    }
  }
}
