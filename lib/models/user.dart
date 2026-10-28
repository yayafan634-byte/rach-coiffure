class AppUser {
  final int? id;
  final String nom;
  final String telephone;
  final String motDePasseHash;
  final String role; // 'admin' ou 'gestionnaire'
  final bool actif;

  AppUser({
    this.id,
    required this.nom,
    required this.telephone,
    required this.motDePasseHash,
    required this.role,
    this.actif = true,
  });

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nom': nom,
        'telephone': telephone,
        'motDePasseHash': motDePasseHash,
        'role': role,
        'actif': actif ? 1 : 0,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'],
        nom: m['nom'],
        telephone: m['telephone'],
        motDePasseHash: m['motDePasseHash'],
        role: m['role'],
        actif: m['actif'] == 1,
      );
}
