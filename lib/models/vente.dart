class Vente {
  final int? id;
  final int? clientId;
  final int? perruqueId;
  final int? prestationId;
  final double montant;
  final int quantite;
  final String
      modePaiement; // 'especes', 'orange_money', 'moov_money', 'mix_yas'
  final String? libelle;
  final double remise;
  final int pointsUtilises;
  final DateTime dateVente;

  Vente({
    this.id,
    this.clientId,
    this.perruqueId,
    this.prestationId,
    required this.montant,
    this.quantite = 1,
    required this.modePaiement,
    this.libelle,
    this.remise = 0,
    this.pointsUtilises = 0,
    DateTime? dateVente,
  }) : dateVente = dateVente ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'clientId': clientId,
        'perruqueId': perruqueId,
        'prestationId': prestationId,
        'montant': montant,
        'quantite': quantite,
        'modePaiement': modePaiement,
        'libelle': libelle,
        'remise': remise,
        'pointsUtilises': pointsUtilises,
        'dateVente': dateVente.toIso8601String(),
      };

  factory Vente.fromMap(Map<String, dynamic> m) => Vente(
        id: m['id'],
        clientId: m['clientId'],
        perruqueId: m['perruqueId'],
        prestationId: m['prestationId'],
        montant: (m['montant'] as num).toDouble(),
        quantite: (m['quantite'] as num?)?.toInt() ?? 1,
        modePaiement: m['modePaiement'],
        libelle: m['libelle'] as String?,
        remise: (m['remise'] as num?)?.toDouble() ?? 0,
        pointsUtilises: (m['pointsUtilises'] as num?)?.toInt() ?? 0,
        dateVente: DateTime.parse(m['dateVente']),
      );
}
