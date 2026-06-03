enum UserRole {
  superAdmin('super_admin', 'Süper Admin'),
  ykSekreteri('yk_sekreteri', 'YK Sekreteri'),
  birimMuduru('birim_muduru', 'Birim Müdürü'),
  birimSekreteri('birim_sekreteri', 'Birim Sekreteri'),
  muhasebe('muhasebe', 'Muhasebe');

  const UserRole(this.value, this.displayName);
  final String value;
  final String displayName;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.birimSekreteri,
    );
  }

  bool get isGlobal =>
      this == UserRole.superAdmin || this == UserRole.ykSekreteri;
}

class UserModel {
  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.birimId,
    this.universiteId,
    this.aktif = true,
  });

  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final String? birimId;
  final String? universiteId;
  final bool aktif;

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String? ?? 'birim_sekreteri'),
      birimId: map['birimId'] as String?,
      universiteId: map['universiteId'] as String?,
      aktif: map['aktif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'role': role.value,
      'birimId': birimId,
      'universiteId': universiteId,
      'aktif': aktif,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? email,
    UserRole? role,
    String? birimId,
    String? universiteId,
    bool? aktif,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      birimId: birimId ?? this.birimId,
      universiteId: universiteId ?? this.universiteId,
      aktif: aktif ?? this.aktif,
    );
  }
}
