import 'permission.dart';

class AppUser {
  final int? id;
  final String nom;
  final String telephone;
  final String motDePasseHash;
  final String role; // 'admin' ou 'gestionnaire'
  final bool actif;
  final Set<String> permissions;
  final bool doitChangerMotDePasse;

  AppUser({
    this.id,
    required this.nom,
    required this.telephone,
    required this.motDePasseHash,
    required this.role,
    this.actif = true,
    this.permissions = const {},
    this.doitChangerMotDePasse = false,
  });

  bool get isAdmin => role == 'admin';

  bool peut(String cle) => isAdmin || permissions.contains(cle);

  AppUser copyWith({
    int? id,
    String? nom,
    String? telephone,
    String? motDePasseHash,
    String? role,
    bool? actif,
    Set<String>? permissions,
    bool? doitChangerMotDePasse,
  }) =>
      AppUser(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        telephone: telephone ?? this.telephone,
        motDePasseHash: motDePasseHash ?? this.motDePasseHash,
        role: role ?? this.role,
        actif: actif ?? this.actif,
        permissions: permissions ?? this.permissions,
        doitChangerMotDePasse:
            doitChangerMotDePasse ?? this.doitChangerMotDePasse,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nom': nom,
        'telephone': telephone,
        'motDePasseHash': motDePasseHash,
        'role': role,
        'actif': actif ? 1 : 0,
        'permissions': permissions.join(','),
        'doitChangerMotDePasse': doitChangerMotDePasse ? 1 : 0,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) {
    final brut = m['permissions'] as String?;
    final permissions = brut == null
        ? kPermissionsGestionnaireParDefaut
        : brut
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toSet();
    return AppUser(
      id: m['id'],
      nom: m['nom'],
      telephone: m['telephone'],
      motDePasseHash: m['motDePasseHash'],
      role: m['role'],
      actif: m['actif'] == 1,
      permissions: permissions,
      doitChangerMotDePasse: m['doitChangerMotDePasse'] == 1,
    );
  }
}
