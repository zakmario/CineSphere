import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/pages/actualites/actualites_page_widget.dart';
import '/pages/onboarding/onboarding_page_widget.dart';
import '/pages/shared/main_nav_bar.dart';
import '/pages/profile/profile_page_widget.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
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
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: false,
          title: Text(
            'CineSphere',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: Colors.white,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualités',
              onPressed: () => context.push(ActualitesPageWidget.routePath),
              icon: const Icon(Icons.newspaper_outlined, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Mon profil',
              onPressed: () => context.push(ProfilePageWidget.routePath),
              icon: const Icon(Icons.person_outline, color: Colors.white),
            ),
          ],
          centerTitle: false,
          elevation: 2.0,
        ),
        bottomNavigationBar: const MainNavBar(currentIndex: 0),
        body: SafeArea(
          top: true,
          child: custom_widgets.HomeFeed(
            onItemTap: (tappedMediaId) =>
                openMediaDetail(context, tappedMediaId),
            onOnboardingRequired: () async {
              if (context.mounted) context.go(OnboardingPageWidget.routePath);
            },
          ),
        ),
      ),
    );
  }
}
