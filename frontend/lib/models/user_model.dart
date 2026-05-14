class UserModel {
  final int idUser;
  final String email;
  final String last_name;
  final String first_name;
  final String phone;
  final int age;
  final String gender;
  final DateTime createdAt;

  UserModel({
    required this.idUser,
    required this.email,
    required this.last_name,
    required this.first_name,
    required this.phone,
    required this.age,
    required this.gender,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      idUser: json['id_user'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      last_name: json['last_name'] as String? ?? '',
      first_name: json['first_name'] as String? ?? '',
      phone: json['phone'] as String? ?? 'Non renseigné',
      age: json['age'] as int? ?? 0,
      gender: json['gender'] as String? ?? 'Non renseigné',
      createdAt: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id_user': idUser,
        'email': email,
        'last_name': last_name,
        'first_name': first_name,
        'phone': phone,
        'age': age,
        'gender': gender,
        'creation_date': createdAt.toIso8601String(),
      };
}
