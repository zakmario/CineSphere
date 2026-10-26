import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'confirmation_email_widget.dart' show ConfirmationEmailWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ConfirmationEmailModel extends FlutterFlowModel<ConfirmationEmailWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - authConfirmSignUp] action in ConfirmButton widget.
  String? verification;
  // Stores action output result for [Custom Action - syncTmdbCatalog] action in ConfirmButton widget.
  String? syncTmdb;
  // Stores action output result for [Custom Action - authResendCode] action in Text widget.
  String? renvoi;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
