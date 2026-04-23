class AppConfig {
  static const String baseUrl =
      'https://us-central1-rms-app-3d585.cloudfunctions.net';

  static String functionsUrl(String endpoint) => '$baseUrl/$endpoint';
}