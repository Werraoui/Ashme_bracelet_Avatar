class PredictResult {
  final String id;
  final String id_user;
  final String id_physio;
  final String status_predict;
  final DateTime createdAt;

  PredictResult({
    required this.id,
    required this.id_user,
    required this.id_physio,
    required this.status_predict,
    required this.createdAt,
  });

  factory PredictResult.fromJson(Map<String, dynamic> json) {
    return PredictResult(
      id: json['id_predict']?.toString() ?? '0',
      id_user: json['id_user']?.toString() ?? '0',
      id_physio: json['id_physio']?.toString() ?? '0',
      status_predict: json['status_predict']?.toString() ?? '',
      createdAt: json['time_of_creation'] != null
          ? DateTime.tryParse(json['time_of_creation'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id_predict': id,
        'id_user': id_user,
        'id_physio': id_physio,
        'status_predict': status_predict,
        'time_of_creation': createdAt.toIso8601String(),
      };
}
