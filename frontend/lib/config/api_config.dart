/// API backend Render — AVATAR
class ApiConfig {
  static const String baseUrl = 'https://ashme-bracelet-avatar.onrender.com';

  static String get signupUrl => '$baseUrl/auth/signup';
  static String get signinUrl => '$baseUrl/auth/signin-json';
  static String get logoutUrl => '$baseUrl/auth/logout';

  static String userUrl(int id) => '$baseUrl/users/$id';

  static String latestPhysioUrl(int userId) =>
      '$baseUrl/readings/latest/$userId';
  static String physioHistoryUrl(int userId) =>
      '$baseUrl/readings/history/$userId';

  static String latestPredictionUrl(int userId) =>
      '$baseUrl/predictions/latest/$userId';
  static String predictionHistoryUrl(int userId) =>
      '$baseUrl/predictions/history/$userId';

  static String get readingsUrl => '$baseUrl/readings';

  static String alertsUrl(int userId) => '$baseUrl/alerts/$userId';
  static String ackAlertUrl(int alertId) => '$baseUrl/alerts/$alertId/ack';

  static String contactsUrl(int userId) => '$baseUrl/contacts/$userId';
  static String get createContactUrl => '$baseUrl/contacts';
}
