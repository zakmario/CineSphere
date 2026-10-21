import 'dart:convert';
import 'dart:io';

import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-1111-1111-111111111111';
const _picker = MethodChannel('plugins.flutter.io/image_picker');

final _requests = <String>[];
Map<String, dynamic>? _profilePatch;

String _jwt() {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 1));
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': _userId, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}'
      '.signature';
}

http.Response _json(http.Request request, Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'}, request: request);

Future<http.Response> _handler(http.Request request) async {
  _requests.add('${request.method} ${request.url.path}');
  if (request.url.path.startsWith('/storage/v1/object/avatars/')) {
    return _json(request, {'Key': 'avatars/$_userId/avatar.png'});
  }
  if (request.url.path == '/rest/v1/profiles') {
    _profilePatch = jsonDecode(request.body) as Map<String, dynamic>;
    return _json(request, {
      'id': _userId,
      'username': 'zak',
      'avatar_url': _profilePatch!['avatar_url'],
      'role': 'user',
    });
  }
  return _json(request, []);
}

void main() {
  late Directory tmp;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('avatar_test');
    // Dossiers de cache de CachedNetworkImage (path_provider).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => tmp.path);
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient(_handler),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    await Supabase.instance.client.auth.recoverSession(jsonEncode({
      'access_token': _jwt(),
      'token_type': 'bearer',
      'expires_in': 86400,
      'refresh_token': 'refresh',
      'user': {
        'id': _userId,
        'aud': 'authenticated',
        'email': 'zak@example.com',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-10-20T09:30:00Z',
      },
    }));
  });

  tearDownAll(() async {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows garde parfois le fichier ouvert : le dossier temporaire reste.
    }
  });

  setUp(() {
    _requests.clear();
    _profilePatch = null;
  });

  void fakeGallery(String? path) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_picker, (call) async {
      expect(call.method, 'pickImage');
      expect(call.arguments['maxWidth'], 512);
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

  testWidgets('choisir une image : envoi dans avatars puis profil mis à jour',
      (tester) async {
    final file = File('${tmp.path}/photo.png')
      ..writeAsBytesSync(List.filled(64, 1));
    fakeGallery(file.path);
    final changes = <String>[];
    await pump(tester, changes: changes);

    await tester.tap(find.bySemanticsLabel('Changer la photo de profil'));
    await settle(tester);

    expect(_requests, [
      'POST /storage/v1/object/avatars/$_userId/avatar.png',
      'PATCH /rest/v1/profiles',
    ]);
    expect(_profilePatch!['avatar_url'],
        startsWith('https://test.supabase.co/storage/v1/object/public/avatars/'
            '$_userId/avatar.png?v='));
    expect(changes, [_profilePatch!['avatar_url']]);
    expect(find.text('Photo de profil mise à jour'), findsOneWidget);
    // Laisse disparaître le message et les minuteurs du cache d'images.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('galerie fermée sans choix : rien n\'est envoyé', (tester) async {
    fakeGallery(null);
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Changer la photo de profil'));
    await settle(tester);
    expect(_requests, isEmpty);
  });

  testWidgets('image trop lourde : message et pas d\'envoi', (tester) async {
    final file = File('${tmp.path}/big.jpg')
      ..writeAsBytesSync(List.filled(2 * 1024 * 1024 + 1, 0));
    fakeGallery(file.path);
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Changer la photo de profil'));
    await settle(tester);
    expect(_requests, isEmpty);
    expect(find.text('L’image dépasse 2 Mo.'), findsOneWidget);
  });
}
