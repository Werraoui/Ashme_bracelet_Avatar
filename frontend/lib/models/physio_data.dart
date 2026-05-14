class PhysioData {
  final String id;
  final String id_user;
  final double spo2;
  final double heartRate;
  final double respiratoryRate;
  final DateTime createdAt;

  PhysioData({
    required this.id,
    required this.id_user,
    required this.spo2,
    required this.heartRate,
    required this.respiratoryRate,
    required this.createdAt,
  });

  factory PhysioData.fromJson(Map<String, dynamic> json) {
    return PhysioData(
      id: json['id_physio']?.toString() ?? '0',
      id_user: json['id_user']?.toString() ?? '0',
      spo2: (json['spo2_value'] as num?)?.toDouble() ?? 0.0,
      heartRate: (json['hr_value'] as num?)?.toDouble() ?? 0.0,
      respiratoryRate: (json['rr_value'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['time_of_record'] != null
          ? DateTime.tryParse(json['time_of_record'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id_physio': id,
        'id_user': id_user,
        'spo2_value': spo2,
        'hr_value': heartRate,
        'rr_value': respiratoryRate,
        'time_of_record': createdAt.toIso8601String(),
      };
}
