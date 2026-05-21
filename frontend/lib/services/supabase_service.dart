import 'api_service.dart';
import 'bracelet_service.dart';
import '../models/physio_data.dart';
import '../models/predict_model.dart';
import '../models/alerte_model.dart';
import '../models/user_model.dart';

/// Compatibility layer that delegates all calls to [ApiService].
/// The UI code previously used SupabaseService; it now talks to the FastAPI
/// backend through [ApiService] without any Supabase dependency.
class SupabaseService {
  final _api = ApiService();
  final _bracelet = BraceletService();

  /// Bracelet → API Render → modèle FCM → Supabase (physio + predic_results).
  Future<({PhysioData physio, PredictResult prediction})> syncBraceletWithAi() {
    return _bracelet.syncReadingToAi();
  }

  Future<PhysioData?> getLatestPhysio() async {
    final userId = await _api.getUserId();
    if (userId == null) throw Exception('Not authenticated');
    return _api.getLatestPhysio(userId);
  }

  Future<PredictResult?> getLatestPrediction() async {
    final userId = await _api.getUserId();
    if (userId == null) throw Exception('Not authenticated');
    return _api.getLatestPrediction(userId);
  }

  Future<List<Alerte>> getAlertes() async {
    final userId = await _api.getUserId();
    if (userId == null) throw Exception('Not authenticated');
    return _api.getAlerts(userId);
  }

  Future<UserModel?> getUserById(int userId) async {
    try {
      return await _api.getUser(userId);
    } catch (_) {
      return null;
    }
  }
}
