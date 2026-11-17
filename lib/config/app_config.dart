class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.139.51.139:8000',
  );

  /// Build with --dart-define=DEMO_MODE=true to run without a server,
  /// using the in-app demo backend (lib/demo). Used for the GitHub Pages demo.
  static const bool isDemo = bool.fromEnvironment('DEMO_MODE');
}
