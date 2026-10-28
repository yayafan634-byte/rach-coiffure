class MouvementStock {
  final int? id;
  final int perruqueId;
  final String nomPerruque;
  final int delta;
  final String type; // 'entree', 'sortie', 'ajustement'
  final String? motif;
  final DateTime date;

  MouvementStock({
    this.id,
    required this.perruqueId,
    this.nomPerruque = '',
    required this.delta,
    required this.type,
    this.motif,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  bool get estEntree => delta > 0;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'perruqueId': perruqueId,
        'delta': delta,
        'type': type,
        'motif': motif,
        'date': date.toIso8601String(),
      };

  factory MouvementStock.fromMap(Map<String, dynamic> m) => MouvementStock(
        id: m['id'],
        perruqueId: m['perruqueId'],
        nomPerruque: (m['nomPerruque'] as String?) ?? '',
        delta: m['delta'],
        type: m['type'],
        motif: m['motif'],
        date: DateTime.parse(m['date']),
      );
}
