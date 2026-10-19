import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  static bool get isSignedIn =>
      isConfigured && Supabase.instance.client.auth.currentSession != null;

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        'Supabase is not configured. Pass SUPABASE_URL and '
        'SUPABASE_ANON_KEY with --dart-define.',
      );
      return;
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
  }

  static SupabaseClient get client {
    if (!isConfigured) {
      throw StateError(
        'Supabase is not configured. Pass SUPABASE_URL and '
        'SUPABASE_ANON_KEY with --dart-define.',
      );
    }
    return Supabase.instance.client;
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  static Future<void> signOut() => client.auth.signOut();

  static Future<Map<String, dynamic>?> loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final profile = await client
        .from('profiles')
        .select('username, email, avatar_url, bio')
        .eq('id', user.id)
        .maybeSingle();
    return profile;
  }

  static Future<void> updateProfile({
    required String username,
    required String bio,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('A signed-in user is required to update a profile.');
    }

    await client.from('profiles').upsert({
      'id': user.id,
      'username': username,
      'email': user.email,
      'bio': bio,
    });
  }
}
