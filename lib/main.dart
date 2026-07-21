/// Sourcely — Multi-Source RAG Knowledge Assistant
///
/// Main application entrypoint. Initializes Supabase, sets up providers,
/// and launches the app with the premium dark theme.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/constants.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/spaces_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  runApp(const SourcelyApp());
}

class SourcelyApp extends StatelessWidget {
  const SourcelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseClient = Supabase.instance.client;
    final authService = AuthService(supabaseClient);
    final apiService = ApiService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService, apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => SpacesProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Sourcely — AI Knowledge Assistant',
        debugShowCheckedModeBanner: false,
        theme: SourcelyTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
