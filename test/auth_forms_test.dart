import 'package:cine_sphere/custom_code/actions/auth_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_auth_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

Future<void> _enter(WidgetTester tester, String label, String text) =>
    tester.enterText(_field(label), text);

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAuthGateway gateway;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    gateway = FakeAuthGateway();
    AuthService.debugInstance = AuthService(gateway);
  });

  tearDown(() => AuthService.debugInstance = null);

  group('LoginForm', () {
    testWidgets('valide les champs avant d\'appeler Supabase', (tester) async {
      await tester.pumpWidget(_wrap(const LoginForm()));
      await _tap(tester, 'Se connecter');

      expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
      expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
      expect(gateway.calls, isEmpty);
    });

    testWidgets('connexion réussie : appelle onSignedIn', (tester) async {
      var signedIn = 0;
      await tester
          .pumpWidget(_wrap(LoginForm(onSignedIn: () async => signedIn++)));
      await _enter(tester, 'Adresse e-mail', 'zak@example.com');
      await _enter(tester, 'Mot de passe', 'secret123');
      await _tap(tester, 'Se connecter');

      expect(gateway.calls, ['signIn zak@example.com']);
      expect(signedIn, 1);
    });

    testWidgets('affiche l\'erreur en français', (tester) async {
      gateway.error = const AuthException('Invalid login credentials');
      var signedIn = 0;
      await tester
          .pumpWidget(_wrap(LoginForm(onSignedIn: () async => signedIn++)));
      await _enter(tester, 'Adresse e-mail', 'zak@example.com');
      await _enter(tester, 'Mot de passe', 'mauvais');
      await _tap(tester, 'Se connecter');

      expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
      expect(signedIn, 0);
    });

    testWidgets('e-mail non confirmé : propose de saisir le code',
        (tester) async {
      var signedIn = 0;
      await tester
          .pumpWidget(_wrap(LoginForm(onSignedIn: () async => signedIn++)));
      await _enter(tester, 'Adresse e-mail', 'zak@example.com');
      await _enter(tester, 'Mot de passe', 'secret123');
      gateway.errors['signIn'] = const AuthException('Email not confirmed',
          code: 'email_not_confirmed');
      await _tap(tester, 'Se connecter');

      expect(find.text('Confirmez votre adresse'), findsOneWidget);
      expect(gateway.calls,
          ['signIn zak@example.com', 'resendSignUpCode zak@example.com']);
      expect(find.text('Un nouveau code a été envoyé à zak@example.com.'),
          findsOneWidget);

      await _enter(tester, 'Code reçu par e-mail', '12345678');
      await _tap(tester, 'Valider le code');
      expect(gateway.calls.last, 'verifySignUpCode zak@example.com 12345678');
      expect(signedIn, 1);
      await tester.pump(kResendCooldown);
    });

    testWidgets('liens vers inscription et mot de passe oublié',
        (tester) async {
      var created = 0;
      var forgot = 0;
      await tester.pumpWidget(_wrap(LoginForm(
        onCreateAccount: () async => created++,
        onForgotPassword: () async => forgot++,
      )));
      await _tap(tester, 'Créer un compte');
      await _tap(tester, 'Mot de passe oublié ?');
      expect((created, forgot), (1, 1));
    });

    testWidgets('bouton afficher / masquer le mot de passe', (tester) async {
      await tester.pumpWidget(_wrap(const LoginForm()));
      EditableText editable() => tester.widget<EditableText>(find.descendant(
          of: _field('Mot de passe'), matching: find.byType(EditableText)));

      expect(editable().obscureText, isTrue);
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      expect(editable().obscureText, isFalse);
    });
  });

  group('SignUpForm', () {
    Future<void> fill(WidgetTester tester,
        {String username = 'zak', String confirmation = 'secret123'}) async {
      await _enter(tester, 'Pseudo', username);
      await _enter(tester, 'Adresse e-mail', 'zak@example.com');
      await _enter(tester, 'Mot de passe', 'secret123');
      await _enter(tester, 'Confirmer le mot de passe', confirmation);
    }

    testWidgets('vérifie le pseudo pendant la saisie (debounce)',
        (tester) async {
      gateway.takenUsernames.add('zak');
      await tester.pumpWidget(_wrap(const SignUpForm()));
      await _enter(tester, 'Pseudo', 'za');
      await _enter(tester, 'Pseudo', 'zak');
      await tester.pump(const Duration(milliseconds: 300));
      expect(gateway.calls, isEmpty);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(gateway.calls, ['isUsernameAvailable zak']);
      expect(find.bySemanticsLabel('Pseudo déjà utilisé'), findsOneWidget);

      await _enter(tester, 'Pseudo', 'zak22');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.bySemanticsLabel('Pseudo disponible'), findsOneWidget);
      expect(find.text('Ce pseudo est disponible.'), findsOneWidget);
    });

    testWidgets('mots de passe différents', (tester) async {
      await tester.pumpWidget(_wrap(const SignUpForm()));
      await fill(tester, confirmation: 'autre-chose');
      await _tap(tester, 'Créer mon compte');

      expect(
          find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
      expect(gateway.calls.where((c) => c.startsWith('signUp')), isEmpty);
    });

    testWidgets('inscription directe : appelle onSignedUp', (tester) async {
      var signedUp = 0;
      await tester
          .pumpWidget(_wrap(SignUpForm(onSignedUp: () async => signedUp++)));
      await fill(tester);
      await _tap(tester, 'Créer mon compte');

      expect(gateway.calls.last, 'signUp zak@example.com zak');
      expect(signedUp, 1);
    });

    testWidgets('confirmation par code', (tester) async {
      gateway.signUpOutcome = SignUpOutcome.confirmationRequired;
      var signedUp = 0;
      await tester
          .pumpWidget(_wrap(SignUpForm(onSignedUp: () async => signedUp++)));
      await fill(tester);
      await _tap(tester, 'Créer mon compte');

      expect(find.text('Vérifiez vos e-mails'), findsOneWidget);
      expect(find.text('Renvoyer le code dans 60 s'), findsOneWidget);
      expect(signedUp, 0);

      await _enter(tester, 'Code reçu par e-mail', '123456');
      await _tap(tester, 'Activer mon compte');
      expect(gateway.calls.last, 'verifySignUpCode zak@example.com 123456');
      expect(signedUp, 1);
    });

    testWidgets('renvoi du code après le délai', (tester) async {
      gateway.signUpOutcome = SignUpOutcome.confirmationRequired;
      await tester.pumpWidget(_wrap(const SignUpForm()));
      await fill(tester);
      await _tap(tester, 'Créer mon compte');

      await tester.pump(kResendCooldown);
      await tester.pump();
      await _tap(tester, 'Renvoyer le code');
      expect(gateway.calls.last, 'resendSignUpCode zak@example.com');
      expect(find.text('Code renvoyé à zak@example.com.'), findsOneWidget);
      // Le délai repart : on laisse le minuteur se terminer.
      await tester.pump(kResendCooldown);
    });

    testWidgets('pseudo pris au moment de l\'inscription', (tester) async {
      gateway.takenUsernames.add('zak');
      await tester.pumpWidget(_wrap(const SignUpForm()));
      await fill(tester);
      await _tap(tester, 'Créer mon compte');
      expect(find.text('Ce pseudo est déjà utilisé.'), findsWidgets);
    });
  });

  group('ForgotPasswordForm', () {
    testWidgets('envoie le code et transmet l\'e-mail', (tester) async {
      String? sentTo;
      await tester.pumpWidget(_wrap(
          ForgotPasswordForm(onCodeSent: (email) async => sentTo = email)));
      await _enter(tester, 'Adresse e-mail', ' zak@example.com ');
      await _tap(tester, 'Envoyer le code');

      expect(gateway.calls, ['sendPasswordResetCode zak@example.com']);
      expect(sentTo, 'zak@example.com');
    });

    testWidgets('limite d\'envoi atteinte', (tester) async {
      gateway.error =
          const AuthException('x', code: 'over_email_send_rate_limit');
      String? sentTo;
      await tester.pumpWidget(_wrap(
          ForgotPasswordForm(onCodeSent: (email) async => sentTo = email)));
      await _enter(tester, 'Adresse e-mail', 'zak@example.com');
      await _tap(tester, 'Envoyer le code');

      expect(find.textContaining('Trop d\'e-mails envoyés'), findsOneWidget);
      expect(sentTo, isNull);
    });
  });

  group('NewPasswordForm', () {
    testWidgets('avec e-mail : code puis nouveau mot de passe', (tester) async {
      var updated = 0;
      await tester.pumpWidget(_wrap(NewPasswordForm(
        email: 'zak@example.com',
        onPasswordUpdated: () async => updated++,
      )));
      expect(find.text('Adresse e-mail'), findsNothing);

      await _enter(tester, 'Code reçu par e-mail', '12345678');
      await _enter(tester, 'Nouveau mot de passe', 'nouveau123');
      await _enter(tester, 'Confirmer le mot de passe', 'nouveau123');
      await _tap(tester, 'Enregistrer le mot de passe');

      expect(gateway.calls, [
        'verifyRecoveryCode zak@example.com 12345678',
        'updatePassword nouveau123',
      ]);
      expect(updated, 1);
      await tester.pump(kResendCooldown);
    });

    testWidgets('membre connecté : seulement le mot de passe', (tester) async {
      gateway.session = true;
      await tester.pumpWidget(_wrap(const NewPasswordForm()));
      expect(find.text('Code reçu par e-mail'), findsNothing);

      await _enter(tester, 'Nouveau mot de passe', 'nouveau123');
      await _enter(tester, 'Confirmer le mot de passe', 'nouveau123');
      await _tap(tester, 'Enregistrer le mot de passe');
      expect(gateway.calls, ['updatePassword nouveau123']);
    });

    testWidgets('code accepté mais mot de passe identique : pas de 2e code',
        (tester) async {
      gateway.errors['updatePassword'] =
          const AuthException('x', code: 'same_password');
      await tester
          .pumpWidget(_wrap(const NewPasswordForm(email: 'zak@example.com')));
      await _enter(tester, 'Code reçu par e-mail', '12345678');
      await _enter(tester, 'Nouveau mot de passe', 'ancien123');
      await _enter(tester, 'Confirmer le mot de passe', 'ancien123');
      await _tap(tester, 'Enregistrer le mot de passe');

      expect(find.textContaining('différent de l\'ancien'), findsOneWidget);
      expect(find.text('Code reçu par e-mail'), findsNothing);
      await tester.pump(kResendCooldown);
    });
  });
}
