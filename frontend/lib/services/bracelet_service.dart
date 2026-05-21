import 'dart:math';

import 'api_service.dart';
import '../models/alerte_model.dart';
import '../models/physio_data.dart';
import '../models/predict_model.dart';

/// Envoie les mesures du bracelet à l'API → modèle IA → base de données.
class BraceletService {
  final _api = ApiService();
  final _rng = Random();

  int _spo2 = 96;
  int _hr = 72;
  int _rr = 16;
  int _tick = 0;

  /// Prochaine mesure (simulation : alterne normal / attention / critique).
  ({int spo2, int heartRate, int respiratoryRate}) nextVitals() {
    _tick++;
    switch (_tick % 3) {
      case 0:
        _spo2 = 88;
        _hr = 125;
        _rr = 32;
        break;
      case 1:
        _spo2 = 93;
        _hr = 98;
        _rr = 24;
        break;
      default:
        _spo2 = (_spo2 + _rng.nextInt(3) - 1).clamp(96, 100);
        _hr = (_hr + _rng.nextInt(5) - 2).clamp(65, 85);
        _rr = (_rr + _rng.nextInt(3) - 1).clamp(14, 18);
    }
    return (spo2: _spo2, heartRate: _hr, respiratoryRate: _rr);
  }

  /// POST /readings : enregistre physio_variables + lance le modèle FCM + predic_results.
  Future<({PhysioData physio, PredictResult prediction, List<Alerte> alerts})>
      syncReadingToAi({
    int? spo2,
    int? heartRate,
    int? respiratoryRate,
  }) async {
    final userId = await _api.getUserId();
    if (userId == null) {
      throw Exception('Non connecté');
    }

    final vitals = nextVitals();
    return _api.postReadingWithPrediction(
      userId: userId,
      spo2: spo2 ?? vitals.spo2,
      heartRate: heartRate ?? vitals.heartRate,
      respiratoryRate: respiratoryRate ?? vitals.respiratoryRate,
    );
  }
}
