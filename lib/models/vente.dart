class Vente {
  final int? id;
  final int? clientId;
  final int? perruqueId;
  final int? prestationId;
  final double montant;
  final int quantite;
  final String modePaiement; // 'especes', 'orange_money', 'moov_money', 'mix_yas'
  final DateTime dateVente;

  Vente({
    this.id,
    this.clientId,
    this.perruqueId,
    this.prestationId,
    required this.montant,
    this.quantite = 1,
    required this.modePaiement,
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
        dateVente: DateTime.parse(m['dateVente']),
      );
}
