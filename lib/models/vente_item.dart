class VenteItem {
  final int? id;
  final int venteId;
  final int? perruqueId;
  final String? libelle;
  final double prixUnitaire;
  final int quantite;
  final double montant;

  const VenteItem({
    this.id,
    required this.venteId,
    this.perruqueId,
    this.libelle,
    required this.prixUnitaire,
    required this.quantite,
    required this.montant,
  });

  String get designation {
    final l = libelle?.trim();
    if (l != null && l.isNotEmpty) return l;
    return perruqueId == null ? 'Vente libre' : 'Article #$perruqueId';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'venteId': venteId,
        'perruqueId': perruqueId,
        'libelle': libelle,
        'prixUnitaire': prixUnitaire,
        'quantite': quantite,
        'montant': montant,
      };

  factory VenteItem.fromMap(Map<String, dynamic> m) => VenteItem(
        id: m['id'],
        venteId: m['venteId'],
        perruqueId: m['perruqueId'],
        libelle: m['libelle'] as String?,
        prixUnitaire: (m['prixUnitaire'] as num).toDouble(),
        quantite: (m['quantite'] as num).toInt(),
        montant: (m['montant'] as num).toDouble(),
      );
}
