import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sourcely/screens/auth/login_screen.dart';
import 'package:sourcely/providers/auth_provider.dart';
import 'package:sourcely/providers/theme_provider.dart';

class FakeThemeProvider extends ChangeNotifier implements ThemeProvider {
  @override
  ThemeMode get themeMode => ThemeMode.dark;
  @override
  bool get isDarkMode => true;
  @override
  Future<void> toggleTheme() async {}
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  User? get user => null;
  @override
  bool get isLoggedIn => false;
  @override
  Future<bool> signUp({required String email, required String password}) async => false;
  @override
  Future<bool> signIn({required String email, required String password}) async => false;
  @override
  Future<void> signOut() async {}
  @override
  void clearError() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration/Widget Test', () {
    testWidgets('LoginScreen renders correctly and accepts input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => FakeThemeProvider()),
            ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify the login screen renders its elements
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      // Test input
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.pump();
      expect(find.text('test@example.com'), findsOneWidget);
    });
  });
}
