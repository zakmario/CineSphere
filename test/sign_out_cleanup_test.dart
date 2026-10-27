import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/actions/sign_out_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => CineFirebaseService.debugInstance = FakeCineFirebaseService());
  tearDown(() => CineFirebaseService.debugInstance = null);

  test('efface rappels et genres du membre, garde l\'onboarding', () async {
    SharedPreferences.setMockInitialValues({
      'cs_reminders': ['movie_550_2026-11-01'],
      'cs_favorite_genres': ['Drame'],
      'cs_onboarding_done': true,
    });

    // Sans plugin de notifications (tests), l'annulation est ignorée.
    await signOutCleanup();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('cs_reminders'), isNull);
    expect(prefs.getStringList('cs_favorite_genres'), isNull);
    expect(prefs.getBool('cs_onboarding_done'), isTrue);
  });
}
