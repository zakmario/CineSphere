import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'inscription_widget.dart' show InscriptionWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class InscriptionModel extends FlutterFlowModel<InscriptionWidget> {
  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for UsernameField widget.
  FocusNode? usernameFieldFocusNode;
  TextEditingController? usernameFieldTextController;
  String? Function(BuildContext, String?)? usernameFieldTextControllerValidator;
  String? _usernameFieldTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Choisissez un pseudo.';
    }

    if (val.length < 3) {
      return 'Le pseudo doit contenir au moins 3 caractères.';
    }

    return null;
  }

  // State field(s) for EmailField widget.
  FocusNode? emailFieldFocusNode;
  TextEditingController? emailFieldTextController;
  String? Function(BuildContext, String?)? emailFieldTextControllerValidator;
  String? _emailFieldTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Saisissez votre adresse e-mail.';
    }

    if (!RegExp(kTextValidatorEmailRegex).hasMatch(val)) {
      return 'Adresse e-mail invalide.';
    }
    return null;
  }

  // State field(s) for PasswordField widget.
  late FocusNode passwordFieldPasswordVisibilityFocusNode;
  FocusNode? passwordFieldFocusNode;
  TextEditingController? passwordFieldTextController;
  late bool passwordFieldVisibility;
  String? Function(BuildContext, String?)? passwordFieldTextControllerValidator;
  String? _passwordFieldTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Saisissez un mot de passe.';
    }

    if (val.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }

    return null;
  }

  // State field(s) for ConfirmField widget.
  late FocusNode confirmFieldPasswordVisibilityFocusNode;
  FocusNode? confirmFieldFocusNode;
  TextEditingController? confirmFieldTextController;
  late bool confirmFieldVisibility;
  String? Function(BuildContext, String?)? confirmFieldTextControllerValidator;
  String? _confirmFieldTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Confirmez le mot de passe.';
    }

    return null;
  }

  // Stores action output result for [Custom Action - authSignUp] action in SignUpButton widget.
  String? inscription;

  @override
  void initState(BuildContext context) {
    usernameFieldTextControllerValidator =
        _usernameFieldTextControllerValidator;
    emailFieldTextControllerValidator = _emailFieldTextControllerValidator;
    passwordFieldPasswordVisibilityFocusNode = FocusNode();
    passwordFieldVisibility = false;
    passwordFieldTextControllerValidator =
        _passwordFieldTextControllerValidator;
    confirmFieldPasswordVisibilityFocusNode = FocusNode();
    confirmFieldVisibility = false;
    confirmFieldTextControllerValidator = _confirmFieldTextControllerValidator;
  }

  @override
  void dispose() {
    usernameFieldFocusNode?.dispose();
    usernameFieldTextController?.dispose();

    emailFieldFocusNode?.dispose();
    emailFieldTextController?.dispose();

    passwordFieldFocusNode?.dispose();
    passwordFieldTextController?.dispose();
    passwordFieldPasswordVisibilityFocusNode.dispose();
    confirmFieldFocusNode?.dispose();
    confirmFieldTextController?.dispose();
    confirmFieldPasswordVisibilityFocusNode.dispose();
  }
}
