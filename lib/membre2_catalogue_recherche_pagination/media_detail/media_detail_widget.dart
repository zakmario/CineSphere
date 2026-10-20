import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'media_detail_model.dart';
export 'media_detail_model.dart';

class MediaDetailWidget extends StatefulWidget {
  const MediaDetailWidget({
    super.key,
    this.mediaId,
  });

  final String? mediaId;

  static String routeName = 'MediaDetail';
  static String routePath = '/mediaDetail';

  @override
  State<MediaDetailWidget> createState() => _MediaDetailWidgetState();
}

class _MediaDetailWidgetState extends State<MediaDetailWidget> {
  late MediaDetailModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MediaDetailModel());
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
                child: custom_widgets.MediaDetailView(
                  mediaId: widget!.mediaId!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
