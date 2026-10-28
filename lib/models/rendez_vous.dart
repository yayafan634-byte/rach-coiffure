class RendezVous {
  final int? id;
  final int clientId;
  final int? prestationId;
  final DateTime dateHeure;
  final String statut; // 'prévu', 'terminé', 'annulé'
  final String? note;

  RendezVous({
    this.id,
    required this.clientId,
    this.prestationId,
    required this.dateHeure,
    this.statut = 'prévu',
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'clientId': clientId,
        'prestationId': prestationId,
        'dateHeure': dateHeure.toIso8601String(),
        'statut': statut,
        'note': note,
      };

  factory RendezVous.fromMap(Map<String, dynamic> m) => RendezVous(
        id: m['id'],
        clientId: m['clientId'],
        prestationId: m['prestationId'],
        dateHeure: DateTime.parse(m['dateHeure']),
        statut: m['statut'],
        note: m['note'],
      );
}
