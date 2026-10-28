class Prestation {
  final int? id;
  final String nom;
  final double prix;
  final int dureeMinutes;

  Prestation({
    this.id,
    required this.nom,
    required this.prix,
    required this.dureeMinutes,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nom': nom,
        'prix': prix,
        'dureeMinutes': dureeMinutes,
      };

  factory Prestation.fromMap(Map<String, dynamic> m) => Prestation(
        id: m['id'],
        nom: m['nom'],
        prix: (m['prix'] as num).toDouble(),
        dureeMinutes: m['dureeMinutes'],
      );
}
