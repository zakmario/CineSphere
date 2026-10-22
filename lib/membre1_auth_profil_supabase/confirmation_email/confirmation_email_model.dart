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

  final formKey = GlobalKey<FormState>();
  // State field(s) for CodeField widget.
  FocusNode? codeFieldFocusNode;
  TextEditingController? codeFieldTextController;
  String? Function(BuildContext, String?)? codeFieldTextControllerValidator;
  String? _codeFieldTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Saisissez le code reçu par e-mail.';
    }

    if (val.length < 6) {
      return 'Le code contient au moins 6 chiffres.';
    }

    return null;
  }

  // Stores action output result for [Custom Action - authConfirmSignUp] action in Button widget.
  String? verification;
  // Stores action output result for [Custom Action - syncTmdbCatalog] action in Button widget.
  String? syncTmdb;
  // Stores action output result for [Custom Action - authResendCode] action in Text widget.
  String? renvoi;

  @override
  void initState(BuildContext context) {
    codeFieldTextControllerValidator = _codeFieldTextControllerValidator;
  }

  @override
  void dispose() {
    codeFieldFocusNode?.dispose();
    codeFieldTextController?.dispose();
  }
}
