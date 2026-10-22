import 'package:cine_sphere/custom_code/widgets/trailer_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('youtubeVideoId', () {
    test('formats d\'adresse YouTube', () {
      expect(youtubeVideoId('https://www.youtube.com/watch?v=oGimpDBwkFc'),
          'oGimpDBwkFc');
      expect(youtubeVideoId('https://youtu.be/oGimpDBwkFc'), 'oGimpDBwkFc');
      expect(youtubeVideoId('https://www.youtube.com/embed/oGimpDBwkFc'),
          'oGimpDBwkFc');
      expect(youtubeVideoId(' https://m.youtube.com/watch?v=oGimpDBwkFc '),
          'oGimpDBwkFc');
    });

    test('adresse non YouTube : null', () {
      expect(youtubeVideoId('https://vimeo.com/123456'), isNull);
      expect(youtubeVideoId(''), isNull);
    });
  });

  testWidgets('adresse invalide : message, pas de lecteur', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TrailerPlayer(trailerUrl: 'https://vimeo.com/1')),
    ));
    expect(find.text('Bande-annonce indisponible.'), findsOneWidget);
  });
}
