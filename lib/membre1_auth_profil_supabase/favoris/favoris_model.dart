import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_button_tabbar.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'dart:async';
import 'favoris_widget.dart' show FavorisWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

class FavorisModel extends FlutterFlowModel<FavorisWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for CollectionTabs widget.
  TabController? collectionTabsController;
  int get collectionTabsCurrentIndex =>
      collectionTabsController != null ? collectionTabsController!.index : 0;
  int get collectionTabsPreviousIndex => collectionTabsController != null
      ? collectionTabsController!.previousIndex
      : 0;

  // State field(s) for WatchlistNameField widget.
  FocusNode? watchlistNameFieldFocusNode;
  TextEditingController? watchlistNameFieldTextController;
  String? Function(BuildContext, String?)?
      watchlistNameFieldTextControllerValidator;
  // Stores action output result for [Custom Action - createWatchlist] action in CreateWatchlistButton widget.
  String? creation;
  Completer<List<WatchlistsRecord>>? firestoreRequestCompleter1;
  // Stores action output result for [Custom Action - clearViewHistory] action in ClearHistoryButton widget.
  String? effacement;
  Completer<List<HistoryRecord>>? firestoreRequestCompleter2;
  Completer<List<HistoryRecord>>? firestoreRequestCompleter3;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    collectionTabsController?.dispose();
    watchlistNameFieldFocusNode?.dispose();
    watchlistNameFieldTextController?.dispose();
  }

  /// Additional helper methods.
  Future waitForFirestoreRequestCompleted1({
    double minWait = 0,
    double maxWait = double.infinity,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      await Future.delayed(Duration(milliseconds: 50));
      final timeElapsed = stopwatch.elapsedMilliseconds;
      final requestComplete = firestoreRequestCompleter1?.isCompleted ?? false;
      if (timeElapsed > maxWait || (requestComplete && timeElapsed > minWait)) {
        break;
      }
    }
  }

  Future waitForFirestoreRequestCompleted2({
    double minWait = 0,
    double maxWait = double.infinity,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      await Future.delayed(Duration(milliseconds: 50));
      final timeElapsed = stopwatch.elapsedMilliseconds;
      final requestComplete = firestoreRequestCompleter2?.isCompleted ?? false;
      if (timeElapsed > maxWait || (requestComplete && timeElapsed > minWait)) {
        break;
      }
    }
  }

  Future waitForFirestoreRequestCompleted3({
    double minWait = 0,
    double maxWait = double.infinity,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      await Future.delayed(Duration(milliseconds: 50));
      final timeElapsed = stopwatch.elapsedMilliseconds;
      final requestComplete = firestoreRequestCompleter3?.isCompleted ?? false;
      if (timeElapsed > maxWait || (requestComplete && timeElapsed > minWait)) {
        break;
      }
    }
  }
}
