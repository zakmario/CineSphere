import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'profil_widget.dart' show ProfilWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProfilModel extends FlutterFlowModel<ProfilWidget> {
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

  // State field(s) for BioField widget.
  FocusNode? bioFieldFocusNode;
  TextEditingController? bioFieldTextController;
  String? Function(BuildContext, String?)? bioFieldTextControllerValidator;
  // Stores action output result for [Custom Action - updateMyProfile] action in SaveProfileButton widget.
  String? enregistrement;

  @override
  void initState(BuildContext context) {
    usernameFieldTextControllerValidator =
        _usernameFieldTextControllerValidator;
  }

  @override
  void dispose() {
    usernameFieldFocusNode?.dispose();
    usernameFieldTextController?.dispose();

    bioFieldFocusNode?.dispose();
    bioFieldTextController?.dispose();
  }
}
