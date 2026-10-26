// Remplit Firestore avec les données de référence de CinéSphère
// (cahier des charges, section 5.7) : genres TMDB et plateformes de diffusion
// en France ; avec --release-events, ajoute aussi au calendrier la sortie au
// cinéma des films à venir du catalogue (collection écrite par les admins).
//
// Usage (racine du projet, variables lues dans `.env` ou l'environnement) :
//   dart run tool/seed_firestore.dart [--release-events] [--dry-run]
//
// - FIRESTORE_EMULATOR_HOST=localhost:8080 : écrit dans l'émulateur ;
// - sinon GOOGLE_ACCESS_TOKEN (jeton OAuth) : écrit dans FIREBASE_PROJECT_ID ;
// - TMDB_API_KEY : genres récupérés en français sur TMDB (sinon liste intégrée).
//
// Le script peut être relancé : chaque document est réécrit à l'identique.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Genres TMDB (films et séries) en français, utilisés sans clé TMDB.
const fallbackGenres = <int, String>{
  12: 'Aventure',
  14: 'Fantastique',
  16: 'Animation',
  18: 'Drame',
  27: 'Horreur',
  28: 'Action',
  35: 'Comédie',
  36: 'Histoire',
  37: 'Western',
  53: 'Thriller',
  80: 'Crime',
  99: 'Documentaire',
  878: 'Science-Fiction',
  9648: 'Mystère',
  10402: 'Musique',
  10749: 'Romance',
  10751: 'Familial',
  10752: 'Guerre',
  10759: 'Action & Adventure',
  10762: 'Kids',
  10763: 'News',
  10764: 'Reality',
  10765: 'Science-Fiction & Fantastique',
  10766: 'Soap',
  10767: 'Talk',
  10768: 'War & Politics',
  10770: 'Téléfilm',
};

/// Plateformes (identifiant = fournisseur TMDB ; 0 = sortie en salle).
const platforms = <int, ({String name, String? logo})>{
  0: (name: 'Cinéma', logo: null),
  8: (name: 'Netflix', logo: '/rK1KljqmbvO9HQa1PBFLILWah72.png'),
  119: (name: 'Prime Video', logo: '/gMZdpavHmxFNnLpMHwVxfqeux2g.png'),
  337: (name: 'Disney+', logo: '/5eZ872CghnHFLB1j8grszbrx0dx.png'),
  350: (name: 'Apple TV+', logo: '/9icYBfYFcwgCbky5VdGUIKJ4C5i.png'),
  1899: (name: 'Max', logo: '/skypuy7SXuugIQeYg0IglmzoKaS.png'),
  381: (name: 'Canal+', logo: '/gliWKhLJVdm7QwL1braBCRko5dx.png'),
  531: (name: 'Paramount+', logo: '/pkx3klJlwW5JdtaulvDx6hDNtch.png'),
  283: (name: 'Crunchyroll', logo: '/uFL3c4Cq8M6WoLymlC5Y8bmGytV.png'),
  234: (name: 'Arte', logo: '/ieo2l4zOaljYqJNGxWY8jWryld5.png'),
  1754: (name: 'TF1+', logo: '/j5w5U61YwOM6Adiaa5zuEVqrpP8.png'),
};

const tmdbLogoBase = 'https://image.tmdb.org/t/p/w92';

Future<void> main(List<String> args) async {
  final env = {..._readDotEnv(), ...Platform.environment};
  final dryRun = args.contains('--dry-run');
  final project = env['FIREBASE_PROJECT_ID'] ?? 'cinesphere-app-3f710';
  final emulator = env['FIRESTORE_EMULATOR_HOST'];
  final token = env['GOOGLE_ACCESS_TOKEN'] ?? '';
  if (emulator == null && token.isEmpty && !dryRun) {
    stderr.writeln('Indiquez FIRESTORE_EMULATOR_HOST (émulateur) ou '
        'GOOGLE_ACCESS_TOKEN (vrai projet) dans .env.');
    exit(64);
  }
  final firestore = _Firestore(
    emulator != null
        ? 'http://$emulator/v1/projects/$project/databases/(default)/documents'
        : 'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents',
    // L'émulateur accepte « owner » comme jeton administrateur.
    emulator != null ? 'owner' : token,
    dryRun: dryRun,
  );

  final genres = await _genres(env['TMDB_API_KEY']);
  for (final MapEntry(key: id, value: name) in genres.entries) {
    await firestore.set('genres/$id', {'id': id, 'name': name});
  }
  stdout.writeln('${genres.length} genres');

  for (final MapEntry(key: id, value: p) in platforms.entries) {
    await firestore.set('platforms/$id', {
      'name': p.name,
      'logoUrl': p.logo == null ? null : '$tmdbLogoBase${p.logo}',
    });
  }
  stdout.writeln('${platforms.length} plateformes');

  if (args.contains('--release-events')) {
    final today = DateTime.now().toUtc();
    var count = 0;
    for (final movie in await firestore.list('movies')) {
      final release = movie['releaseDate'] as DateTime?;
      if (release == null || !release.isAfter(today)) {
        continue;
      }
      final tmdbId = movie['tmdbId'] as int;
      final day = release.toIso8601String().substring(0, 10);
      await firestore.set('releaseEvents/movie_${tmdbId}_$day', {
        'mediaType': 'movie',
        'tmdbId': tmdbId,
        'title': 'Sortie au cinéma',
        'posterUrl': movie['posterUrl'],
        'releaseDate': release,
        'platform': 'Cinéma',
      });
      count++;
    }
    stdout.writeln('$count sorties au cinéma');
  }
  if (dryRun) {
    stdout.writeln('(--dry-run : rien n\'a été écrit)');
  }
}

Map<String, String> _readDotEnv() {
  final file = File('.env');
  if (!file.existsSync()) {
    return const {};
  }
  return {
    for (final line in file.readAsLinesSync())
      if (line.contains('=') && !line.trimLeft().startsWith('#'))
        line.substring(0, line.indexOf('=')).trim():
            line.substring(line.indexOf('=') + 1).trim(),
  }..removeWhere((_, v) => v.isEmpty);
}

/// Genres films + séries de TMDB en français, ou la liste intégrée.
Future<Map<int, String>> _genres(String? apiKey) async {
  if (apiKey == null || apiKey.isEmpty) {
    return fallbackGenres;
  }
  final out = <int, String>{};
  for (final kind in ['movie', 'tv']) {
    final response = await http.get(Uri.https('api.themoviedb.org',
        '/3/genre/$kind/list', {'api_key': apiKey, 'language': 'fr-FR'}));
    if (response.statusCode != 200) {
      stderr.writeln('TMDB ${response.statusCode} : liste intégrée utilisée.');
      return fallbackGenres;
    }
    for (final g in (jsonDecode(response.body)['genres'] as List)) {
      out[g['id'] as int] = g['name'] as String;
    }
  }
  return out;
}

/// Client REST Firestore minimal (écriture complète d'un document, lecture
/// d'une collection).
class _Firestore {
  _Firestore(this.base, this.token, {required this.dryRun});

  final String base;
  final String token;
  final bool dryRun;

  Map<String, String> get _headers =>
      {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  Future<void> set(String path, Map<String, Object?> data) async {
    if (dryRun) {
      stdout.writeln('  $path');
      return;
    }
    final response = await http.patch(Uri.parse('$base/$path'),
        headers: _headers,
        body: jsonEncode({
          'fields': {
            for (final e in data.entries)
              if (e.value != null) e.key: _encode(e.value),
          },
        }));
    if (response.statusCode != 200) {
      throw HttpException('$path : ${response.statusCode} ${response.body}');
    }
  }

  Future<List<Map<String, Object?>>> list(String collection) async {
    final out = <Map<String, Object?>>[];
    String? pageToken;
    do {
      final response = await http.get(
          Uri.parse('$base/$collection').replace(queryParameters: {
            'pageSize': '300',
            if (pageToken != null) 'pageToken': pageToken,
          }),
          headers: _headers);
      if (response.statusCode != 200) {
        throw HttpException('$collection : ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      for (final doc in (body['documents'] as List? ?? const [])) {
        final fields = (doc['fields'] as Map<String, dynamic>?) ?? const {};
        out.add({for (final e in fields.entries) e.key: _decode(e.value)});
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null);
    return out;
  }

  static Map<String, Object?> _encode(Object? value) => switch (value) {
        null => {'nullValue': null},
        bool b => {'booleanValue': b},
        int i => {'integerValue': '$i'},
        double d => {'doubleValue': d},
        DateTime t => {'timestampValue': t.toUtc().toIso8601String()},
        List l => {
            'arrayValue': {'values': l.map(_encode).toList()}
          },
        _ => {'stringValue': '$value'},
      };

  static Object? _decode(Object? value) {
    final v = value as Map<String, dynamic>;
    return switch (v.keys.first) {
      'integerValue' => int.parse(v['integerValue'] as String),
      'doubleValue' => (v['doubleValue'] as num).toDouble(),
      'timestampValue' => DateTime.parse(v['timestampValue'] as String),
      'arrayValue' => [
          for (final x in (v['arrayValue']['values'] as List? ?? const []))
            _decode(x)
        ],
      _ => v.values.first,
    };
  }
}
