import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'nouveau_mot_de_passe_model.dart';
export 'nouveau_mot_de_passe_model.dart';

/// Membre 1 — authentification
class NouveauMotDePasseWidget extends StatefulWidget {
  const NouveauMotDePasseWidget({
    super.key,
    this.email,
  });

  final String? email;

  static String routeName = 'NouveauMotDePasse';
  static String routePath = '/nouveauMotDePasse';

  @override
  State<NouveauMotDePasseWidget> createState() =>
      _NouveauMotDePasseWidgetState();
}

class _NouveauMotDePasseWidgetState extends State<NouveauMotDePasseWidget> {
  late NouveauMotDePasseModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NouveauMotDePasseModel());
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
                child: custom_widgets.NewPasswordForm(
                  email: widget!.email,
                  onPasswordUpdated: () async {
                    context.goNamed(HomePageWidget.routeName);
                  },
                  onBack: () async {
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
