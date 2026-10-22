import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/flutter_flow_youtube_player.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'bande_annonce_model.dart';
export 'bande_annonce_model.dart';

/// Membre 1 — lecture d'une bande-annonce dans l'application
class BandeAnnonceWidget extends StatefulWidget {
  const BandeAnnonceWidget({
    super.key,
    this.trailerUrl,
  });

  final String? trailerUrl;

  static String routeName = 'BandeAnnonce';
  static String routePath = '/bandeAnnonce';

  @override
  State<BandeAnnonceWidget> createState() => _BandeAnnonceWidgetState();
}

class _BandeAnnonceWidgetState extends State<BandeAnnonceWidget> {
  late BandeAnnonceModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BandeAnnonceModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubeFullScreenWrapper(
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: Color(0xFF0B0B12),
          body: SafeArea(
            top: true,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(8.0, 8.0, 8.0, 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FlutterFlowIconButton(
                        borderColor: Color(0xFF2A2A3A),
                        borderRadius: 22.0,
                        borderWidth: 1.0,
                        buttonSize: 44.0,
                        fillColor: Color(0xFF15151F),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFFF5F5F7),
                          size: 22.0,
                        ),
                        onPressed: () async {
                          context.pop();
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Bande-annonce',
                          style: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .override(
                                font: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontStyle,
                                ),
                                color: Color(0xFFF5F5F7),
                                fontSize: 20.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontStyle,
                              ),
                        ),
                      ),
                    ].divide(SizedBox(width: 4.0)),
                  ),
                  Container(
                    height: 16.0,
                    decoration: BoxDecoration(),
                  ),
                  FlutterFlowYoutubePlayer(
                    url: widget!.trailerUrl!,
                    autoPlay: true,
                    looping: false,
                    mute: false,
                    showControls: true,
                    showFullScreen: true,
                    strictRelatedVideos: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
