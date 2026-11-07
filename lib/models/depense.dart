class Depense {
  final int? id;
  final String libelle;
  final String? categorie;
  final double montant;
  final DateTime date;

  const Depense({
    this.id,
    required this.libelle,
    this.categorie,
    required this.montant,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'libelle': libelle,
        'categorie': categorie,
        'montant': montant,
        'date': date.toIso8601String(),
      };

  factory Depense.fromMap(Map<String, dynamic> m) => Depense(
        id: m['id'],
        libelle: m['libelle'],
        categorie: m['categorie'] as String?,
        montant: (m['montant'] as num).toDouble(),
        date: DateTime.parse(m['date']),
      );
}
