class Client {
  final int? id;
  final String nom;
  final String telephone;
  final String? adresse;
  final int pointsFidelite;
  final DateTime dateCreation;

  Client({
    this.id,
    required this.nom,
    required this.telephone,
    this.adresse,
    this.pointsFidelite = 0,
    DateTime? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nom': nom,
        'telephone': telephone,
        'adresse': adresse,
        'pointsFidelite': pointsFidelite,
        'dateCreation': dateCreation.toIso8601String(),
      };

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'],
        nom: m['nom'],
        telephone: m['telephone'],
        adresse: m['adresse'],
        pointsFidelite: m['pointsFidelite'],
        dateCreation: DateTime.parse(m['dateCreation']),
      );
}
