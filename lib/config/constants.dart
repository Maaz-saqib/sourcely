/// Sourcely Constants — API URLs, keys, and configuration constants.
library;

class AppConstants {
  AppConstants._();

  /// Backend API base URL
  /// Change this to your deployed backend URL in production
  static const String apiBaseUrl = 'http://localhost:8000/api';

  /// Supabase configuration
  /// Replace these with your actual Supabase project values
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wgaaivnqvqyfhwglooss.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnYWFpdm5xdnF5Zmh3Z2xvb3NzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ1ODA1NzAsImV4cCI6MjEwMDE1NjU3MH0.9q6OfbIxbitC2g2h8mKhKfT7IZVLj3HMtiU_vy05oNQ',
  );

  /// Source type labels and icons
  static const Map<String, String> sourceTypeLabels = {
    'pdf': 'PDF Document',
    'docx': 'Word Document',
    'youtube': 'YouTube Video',
    'url': 'Web Page',
  };

  /// Polling interval for ingestion status (milliseconds)
  static const int statusPollInterval = 3000;

  /// Maximum file size for uploads (50 MB)
  static const int maxFileSize = 50 * 1024 * 1024;
}
