import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fake_firebase_service.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => CineFirebaseService.debugInstance = null);

  testWidgets('déconnecté : invite à se connecter', (tester) async {
    CineFirebaseService.debugInstance = FakeCineFirebaseService(userId: null);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FavoritesGrid())));
    await tester.pump();

    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Connectez-vous pour voir vos favoris.'), findsOneWidget);
    expect(find.text('Actualiser'), findsOneWidget);
  });
}
