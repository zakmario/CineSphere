import 'dart:convert';

import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-1111-1111-111111111111';
const _mediaId = '22222222-2222-2222-2222-222222222222';

/// Lignes simulées de la table `watched` pour le membre connecté.
final _watched = <String>{};
final _requests = <String>[];

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
  final url = request.url;
  if (!url.path.endsWith('/rest/v1/watched')) {
    return _json(request, []);
  }
  _requests.add(request.method);
  switch (request.method) {
    case 'GET':
      final rows = _watched.contains(_mediaId)
          ? [
              {'id': 'w1'}
            ]
          : [];
      final single =
          request.headers['Accept']?.contains('vnd.pgrst.object') ?? false;
      if (single) {
        return rows.isEmpty
            ? _json(request, {'code': 'PGRST116', 'message': 'no rows'},
                status: 406)
            : _json(request, rows.first);
      }
      return _json(request, rows);
    case 'POST':
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {'user_id': _userId, 'media_id': _mediaId});
      _watched.add(_mediaId);
      return http.Response('', 201, request: request);
    case 'DELETE':
      expect(url.queryParameters['media_id'], 'eq.$_mediaId');
      _watched.remove(_mediaId);
      return http.Response('', 204, request: request);
  }
  return _json(request, []);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
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

  setUp(() {
    _watched.clear();
    _requests.clear();
  });

  Future<void> pump(WidgetTester tester, {List<bool>? changes}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkWatchedButton(
          mediaId: _mediaId,
          onChanged: (v) async => changes?.add(v),
        ),
      ),
    ));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('non vu : marquer comme vu puis retirer', (tester) async {
    final changes = <bool>[];
    await pump(tester, changes: changes);
    expect(find.text('Marquer comme vu'), findsOneWidget);

    await tester.tap(find.text('Marquer comme vu'));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Vu'), findsOneWidget);
    expect(find.text('Ajouté à vos titres vus'), findsOneWidget);
    expect(_watched, {_mediaId});

    await tester.tap(find.text('Vu'));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Marquer comme vu'), findsOneWidget);
    expect(_watched, isEmpty);
    expect(changes, [true, false]);
    expect(_requests, ['GET', 'GET', 'POST', 'GET', 'DELETE']);
  });

  testWidgets('déjà vu au chargement', (tester) async {
    _watched.add(_mediaId);
    await pump(tester);
    expect(find.text('Vu'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
