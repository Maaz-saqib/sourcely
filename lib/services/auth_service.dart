/// Auth service for Sourcely — wraps Supabase Auth.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// Get the current user
  User? get currentUser => _client.auth.currentUser;

  /// Whether a user is currently logged in
  bool get isLoggedIn => currentUser != null;

  /// Get the current session's access token
  String? get accessToken => _client.auth.currentSession?.accessToken;

  /// Auth state change stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
