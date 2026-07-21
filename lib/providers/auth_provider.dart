/// Auth Provider for Sourcely — manages authentication state.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiService _apiService;

  bool _isLoading = false;
  String? _errorMessage;
  User? _user;

  AuthProvider(this._authService, this._apiService) {
    _user = _authService.currentUser;
    if (_user != null) {
      _apiService.setAccessToken(_authService.accessToken);
    }

    // Listen for auth state changes
    _authService.authStateChanges.listen((state) {
      _user = state.session?.user;
      if (state.session != null) {
        _apiService.setAccessToken(state.session!.accessToken);
      } else {
        _apiService.setAccessToken(null);
      }
      notifyListeners();
    });
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
      );
      _user = response.user;
      if (response.session != null) {
        _apiService.setAccessToken(response.session!.accessToken);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
      );
      _user = response.user;
      if (response.session != null) {
        _apiService.setAccessToken(response.session!.accessToken);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _apiService.setAccessToken(null);
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
