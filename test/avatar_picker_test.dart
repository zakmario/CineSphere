import 'dart:convert';
import 'dart:io';

import 'package:cine_sphere/custom_code/actions/firestore_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firestore_service.dart';

const _picker = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  late Directory tmp;
  late FakeFirestoreService service;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('avatar_test');
    // Dossiers de cache de CachedNetworkImage (path_provider).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => tmp.path);
  });

  tearDownAll(() async {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows garde parfois le fichier ouvert : le dossier temporaire reste.
    }
  });

  setUp(() {
    service = FakeFirestoreService();
    FirestoreService.debugInstance = service;
  });

  tearDown(() => FirestoreService.debugInstance = null);

  void fakeGallery(String? path) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_picker, (call) async {
      expect(call.method, 'pickImage');
      expect(call.arguments['maxWidth'], 256);
      return path;
    });
  }

  Future<void> pump(WidgetTester tester, {List<String>? changes}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AvatarPicker(
            width: 100,
            height: 100,
            onChanged: (url) async => changes?.add(url),
          ),
        ),
      ));

  /// Laisse le temps aux lectures de fichier et aux requêtes simulées.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  testWidgets('sans photo : icône par défaut et badge appareil photo',
      (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
  });

  testWidgets('choisir une image : enregistrée en base64 dans le profil',
      (tester) async {
    final file = File('${tmp.path}/photo.png')
      ..writeAsBytesSync(List.filled(64, 1));
    fakeGallery(file.path);
    final changes = <String>[];
    await pump(tester, changes: changes);

    await tester.tap(find.bySemanticsLabel('Changer la photo de profil'));
    await settle(tester);

    expect(service.calls, ['uploadAvatar 64']);
    expect(changes, [base64Encode(List.filled(64, 1))]);
    expect(find.text('Photo de profil mise à jour'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('galerie fermée sans choix : rien n\'est envoyé', (tester) async {
    fakeGallery(null);
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Changer la photo de profil'));
    await settle(tester);
    expect(service.calls, isEmpty);
  });

  testWidgets('image trop lourde : message et pas d\'envoi', (tester) async {
    final file = File('${tmp.path}/big.jpg')
      ..writeAsBytesSync(List.filled(kMaxAvatarBytes + 1, 0));
    fakeGallery(file.path);
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Changer la photo de profil'));
    await settle(tester);
    expect(service.calls, isEmpty);
    expect(find.text('Image trop lourde : choisissez-en une autre.'),
        findsOneWidget);
  });
}
