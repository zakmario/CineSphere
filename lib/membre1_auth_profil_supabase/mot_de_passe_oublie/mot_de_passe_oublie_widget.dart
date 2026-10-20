import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'mot_de_passe_oublie_model.dart';
export 'mot_de_passe_oublie_model.dart';

/// Membre 1 — authentification
class MotDePasseOublieWidget extends StatefulWidget {
  const MotDePasseOublieWidget({super.key});

  static String routeName = 'MotDePasseOublie';
  static String routePath = '/motDePasseOublie';

  @override
  State<MotDePasseOublieWidget> createState() => _MotDePasseOublieWidgetState();
}

class _MotDePasseOublieWidgetState extends State<MotDePasseOublieWidget> {
  late MotDePasseOublieModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MotDePasseOublieModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: custom_widgets.ForgotPasswordForm(
                  onCodeSent: (email) async {
                    context.pushNamed(
                      NouveauMotDePasseWidget.routeName,
                      queryParameters: {
                        'email': serializeParam(
                          email,
                          ParamType.String,
                        ),
                      }.withoutNulls,
                    );
                  },
                  onBackToLogin: () async {
                    context.pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
