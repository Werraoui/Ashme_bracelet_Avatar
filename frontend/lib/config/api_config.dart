/// Central configuration for the AVATAR backend API.
///
/// Change [baseUrl] to point to your running backend:
///   - Local Docker:    http://10.0.2.2:8000   (Android emulator)
///   - Local network:   http://192.168.x.x:8000
///   - Production:      https://your-api.domain.com
class ApiConfig {
  // Android emulator uses 10.0.2.2 to reach the host machine's localhost.
  // For a physical device on the same WiFi, use your machine's local IP.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ashme-bracelet-avatar.onrender.com',
  );

  // Auth endpoints
  static String get signupUrl => '$baseUrl/auth/signup';
  static String get signinUrl => '$baseUrl/auth/signin-json';
  static String get logoutUrl => '$baseUrl/auth/logout';

  // User endpoints
  static String userUrl(int id) => '$baseUrl/users/$id';

  // Physio endpoints
  static String latestPhysioUrl(int userId) => '$baseUrl/physio/latest/$userId';
  static String physioHistoryUrl(int userId) =>
      '$baseUrl/physio/history/$userId';

  // Prediction endpoints
  static String latestPredictionUrl(int userId) =>
      '$baseUrl/predictions/latest/$userId';
  static String predictionHistoryUrl(int userId) =>
      '$baseUrl/predictions/history/$userId';

  // Readings (write)
  static String get readingsUrl => '$baseUrl/readings';

  // Alerts endpoints
  static String alertsUrl(int userId) => '$baseUrl/alerts/$userId';
  static String ackAlertUrl(int alertId) => '$baseUrl/alerts/$alertId/ack';

  // Contacts endpoints
  static String contactsUrl(int userId) => '$baseUrl/contacts/$userId';
  static String get createContactUrl => '$baseUrl/contacts';
}
