import 'api_service.dart';
import '../models/user_model.dart';

/// Auth service — wraps [ApiService] to provide sign-in / sign-up / sign-out.
/// All tokens are stored via [ApiService.saveToken].
class AuthService {
  final _api = ApiService();

  /// Sign in with email + password. Returns null on success, error message on failure.
  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      await _api.signIn(email, password);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign up a new user. Returns null on success, error message on failure.
  Future<String?> signUp({
    required String lastName,
    required String firstName,
    required String email,
    required String phone,
    required int age,
    required String gender,
    required String password,
  }) async {
    try {
      await _api.signUp(
        lastName: lastName,
        firstName: firstName,
        email: email,
        phone: phone,
        age: age,
        gender: gender,
        password: password,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _api.signOut();
  }

  Future<int?> getCurrentUserId() async {
    return _api.getUserId();
  }
}
