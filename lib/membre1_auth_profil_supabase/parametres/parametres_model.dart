import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'parametres_widget.dart' show ParametresWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

class ParametresModel extends FlutterFlowModel<ParametresWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - initLocalNotifications] action in Container widget.
  bool? notifications;
  // Stores action output result for [Custom Action - showInstantNotification] action in Container widget.
  bool? test;
  // Stores action output result for [Custom Action - syncTmdbCatalog] action in Container widget.
  String? syncTmdbForce;
  // Stores action output result for [Custom Action - deleteMyAccount] action in Container widget.
  String? suppressionCompte;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
