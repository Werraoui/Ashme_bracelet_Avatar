import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/physio_data.dart';
import '../models/predict_model.dart';
import '../models/alerte_model.dart';
import '../models/user_model.dart';

/// Service responsible for all communication with the AVATAR FastAPI backend.
/// Stores the JWT token in SharedPreferences and attaches it to every
/// authenticated request.
class ApiService {
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';

  // ── Token management ────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  // ── HTTP helpers ────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _assertSuccess(http.Response response, {int expected = 200}) {
    if (response.statusCode != expected) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        detail = decoded['detail']?.toString() ?? response.body;
      } catch (_) {}
      throw Exception('HTTP ${response.statusCode}: $detail');
    }
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Sign in with email + password. Returns the user map on success.
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.signinUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'pass_word': password}),
    );
    _assertSuccess(response);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await saveToken(data['access_token'] as String);
    final user = data['user'] as Map<String, dynamic>;
    await saveUserId(user['id_user'] as int);
    return user;
  }

  /// Sign up a new user.
  Future<Map<String, dynamic>> signUp({
    required String lastName,
    required String firstName,
    required String email,
    required String phone,
    required int age,
    required String gender,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.signupUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'last_name': lastName,
        'first_name': firstName,
        'email': email,
        'phone': phone,
        'age': age,
        'gender': gender,
        'pass_word': password,
      }),
    );
    _assertSuccess(response, expected: 201);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    await clearSession();
  }

  // ── User ─────────────────────────────────────────────────────────────────────

  Future<UserModel> getUser(int userId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(ApiConfig.userUrl(userId)),
      headers: headers,
    );
    _assertSuccess(response);
    return UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── Physio ───────────────────────────────────────────────────────────────────

  Future<PhysioData?> getLatestPhysio(int userId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(ApiConfig.latestPhysioUrl(userId)),
      headers: headers,
    );
    if (response.statusCode == 404) return null;
    _assertSuccess(response);
    return PhysioData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<PhysioData>> getPhysioHistory(int userId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(ApiConfig.physioHistoryUrl(userId)),
      headers: headers,
    );
    _assertSuccess(response);
    final List data = jsonDecode(response.body);
    return data.map((e) => PhysioData.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Envoie une nouvelle mesure physiologique.
  /// Le backend classifie automatiquement le risque et crée les alertes si nécessaire.
  Future<Map<String, dynamic>> postReading({
    required int userId,
    required int spo2,
    required int heartRate,
    required int respiratoryRate,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConfig.readingsUrl),
      headers: headers,
      body: jsonEncode({
        'id_user': userId,
        'spo2_value': spo2,
        'hr_value': heartRate,
        'rr_value': respiratoryRate,
      }),
    );
    _assertSuccess(response, expected: 201);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Predictions ──────────────────────────────────────────────────────────────

  Future<PredictResult?> getLatestPrediction(int userId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(ApiConfig.latestPredictionUrl(userId)),
      headers: headers,
    );
    if (response.statusCode == 404) return null;
    _assertSuccess(response);
    return PredictResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── Alerts ───────────────────────────────────────────────────────────────────

  Future<List<Alerte>> getAlerts(int userId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(ApiConfig.alertsUrl(userId)),
      headers: headers,
    );
    _assertSuccess(response);
    final List data = jsonDecode(response.body);
    return data.map((e) => Alerte.fromApiJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> acknowledgeAlert(int alertId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConfig.ackAlertUrl(alertId)),
      headers: headers,
    );
    _assertSuccess(response);
  }

  // ── Contacts ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getContacts(int userId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(ApiConfig.contactsUrl(userId)),
      headers: headers,
    );
    _assertSuccess(response);
    final List data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createContact({
    required int userId,
    required String name,
    required String phone,
    String? email,
    required String relation,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConfig.createContactUrl),
      headers: headers,
      body: jsonEncode({
        'id_user': userId,
        'name_contact': name,
        'phone_contact': phone,
        if (email != null && email.isNotEmpty) 'email_contact': email,
        'relation': relation,
      }),
    );
    _assertSuccess(response, expected: 201);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateContact(
    int contactId, {
    String? name,
    String? phone,
    String? email,
    String? relation,
  }) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('${ApiConfig.createContactUrl}/$contactId'),
      headers: headers,
      body: jsonEncode({
        if (name != null) 'name_contact': name,
        if (phone != null) 'phone_contact': phone,
        if (email != null) 'email_contact': email,
        if (relation != null) 'relation': relation,
      }),
    );
    _assertSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteContact(int contactId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.createContactUrl}/$contactId'),
      headers: headers,
    );
    _assertSuccess(response);
  }
}
