import '../models/physio_data.dart';
import '../models/predict_model.dart';

/// Aligné sur les seuils du backend (reading_service / prediction_service).
String statusFromVitals(PhysioData? physio) {
  if (physio == null) return 'normal';

  final spo2 = physio.spo2.round();
  final hr = physio.heartRate.round();
  final rr = physio.respiratoryRate.round();

  if (spo2 < 92 || hr > 120 || rr > 30) return 'critical';
  if (spo2 < 95 || rr > 22) return 'warning';
  return 'normal';
}

int _severityRank(String status) {
  switch (status.toLowerCase()) {
    case 'critical':
    case 'critique':
      return 2;
    case 'warning':
    case 'attention':
      return 1;
    default:
      return 0;
  }
}

String normalizeStatus(String? raw) {
  if (raw == null || raw.isEmpty) return 'normal';
  final s = raw.toLowerCase();
  if (s.contains('critical') || s.contains('critique')) return 'critical';
  if (s.contains('warning') || s.contains('attention')) return 'warning';
  return 'normal';
}

/// État affiché : prédiction IA si elle correspond à la mesure, sinon le plus sévère.
String effectiveRiskStatus({
  PhysioData? physio,
  PredictResult? prediction,
}) {
  final fromVitals = statusFromVitals(physio);
  if (prediction == null || physio == null) return fromVitals;

  final predNorm = normalizeStatus(prediction.status_predict);
  final sameReading = prediction.id_physio == physio.id;
  if (!sameReading) return fromVitals;

  return _severityRank(predNorm) >= _severityRank(fromVitals) ? predNorm : fromVitals;
}
