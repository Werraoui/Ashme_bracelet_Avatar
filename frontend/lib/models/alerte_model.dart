class Alerte {
  final String id;
  final String idUser;
  final String idPredict;
  final String? idContact;
  final String? statusPredict;
  final DateTime timeOfAlert;
  final String? stage;
  final String? status;

  Alerte({
    required this.id,
    required this.idUser,
    required this.idPredict,
    this.idContact,
    this.statusPredict,
    required this.timeOfAlert,
    this.stage,
    this.status,
  });

  /// Build from the Supabase joined response (legacy).
  factory Alerte.fromJson(Map<String, dynamic> json) {
    final predicResult = json['predic_results'] as Map<String, dynamic>?;
    return Alerte(
      id: json['id_alerte']?.toString() ?? '0',
      idUser: json['id_user']?.toString() ?? '0',
      idPredict: json['id_predict']?.toString() ?? '0',
      idContact: json['id_contact']?.toString(),
      statusPredict: predicResult?['status_predict']?.toString(),
      timeOfAlert: json['time_of_alert'] != null
          ? DateTime.tryParse(json['time_of_alert'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Build from the FastAPI backend response.
  factory Alerte.fromApiJson(Map<String, dynamic> json) {
    return Alerte(
      id: json['id_alerte']?.toString() ?? '0',
      idUser: json['id_user']?.toString() ?? '0',
      idPredict: json['id_predict']?.toString() ?? '0',
      idContact: json['id_contact']?.toString(),
      statusPredict: json['status_predict']?.toString(),
      timeOfAlert: json['time_of_alert'] != null
          ? DateTime.tryParse(json['time_of_alert'].toString()) ?? DateTime.now()
          : DateTime.now(),
      stage: json['stage']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id_alerte': id,
        'id_user': idUser,
        'id_predict': idPredict,
        'id_contact': idContact,
        'predic_results': {'status_predict': statusPredict},
        'time_of_alert': timeOfAlert.toIso8601String(),
        'stage': stage,
        'status': status,
      };
}
