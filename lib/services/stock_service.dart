import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';

class StockService {
  static final StockService instance = StockService._();
  StockService._();

  Future<Database> get _db async => DbHelper.instance.db;

  /// Met à jour la quantité d'une perruque et enregistre le mouvement
  /// dans une même transaction. [delta] positif = entrée, négatif = sortie.
  Future<String?> changerQuantite({
    required int perruqueId,
    required int delta,
    required String type,
    String? motif,
  }) async {
    if (delta == 0) return 'Quantité nulle';

    final db = await _db;
    return db.transaction<String?>((txn) async {
      final res = await txn.query('perruques',
          columns: ['quantite', 'nom'], where: 'id = ?', whereArgs: [perruqueId]);
      if (res.isEmpty) return 'Article introuvable';

      final actuel = res.first['quantite'] as int;
      final nouveau = actuel + delta;
      if (nouveau < 0) {
        return 'Stock insuffisant (disponible : $actuel)';
      }

      await txn.update('perruques', {'quantite': nouveau},
          where: 'id = ?', whereArgs: [perruqueId]);
      await txn.insert(
          'mouvements_stock',
          MouvementInsert(
            perruqueId: perruqueId,
            delta: delta,
            type: type,
            motif: motif,
          ).toMap());
      return null;
    });
  }

  Future<String?> vendrePerruque({
    required int perruqueId,
    required int quantite,
  }) =>
      changerQuantite(
        perruqueId: perruqueId,
        delta: -quantite,
        type: 'sortie',
        motif: 'Vente',
      );

  Future<String?> entreeStock({
    required int perruqueId,
    required int quantite,
    String? motif,
  }) =>
      changerQuantite(
        perruqueId: perruqueId,
        delta: quantite,
        type: 'entree',
        motif: motif ?? 'Entrée de stock',
      );

  /// Vente de perruque : insère la vente et décrémente le stock
  /// dans une seule transaction.
  Future<String?> vendreAvecStock({
    required int perruqueId,
    required int quantite,
    required double montant,
    required String modePaiement,
    int? clientId,
  }) async {
    if (quantite <= 0) return 'Quantité invalide';
    if (montant <= 0) return 'Montant invalide';

    final db = await _db;
    return db.transaction<String?>((txn) async {
      final res = await txn.query('perruques',
          columns: ['quantite'], where: 'id = ?', whereArgs: [perruqueId]);
      if (res.isEmpty) return 'Article introuvable';

      final actuel = res.first['quantite'] as int;
      if (actuel < quantite) {
        return 'Stock insuffisant (disponible : $actuel)';
      }

      await txn.update('perruques', {'quantite': actuel - quantite},
          where: 'id = ?', whereArgs: [perruqueId]);
      await txn.insert(
          'mouvements_stock',
          MouvementInsert(
            perruqueId: perruqueId,
            delta: -quantite,
            type: 'sortie',
            motif: 'Vente',
          ).toMap());
      await txn.insert('ventes', {
        if (clientId != null) 'clientId': clientId,
        'perruqueId': perruqueId,
        'montant': montant,
        'quantite': quantite,
        'modePaiement': modePaiement,
        'dateVente': DateTime.now().toIso8601String(),
      });
      return null;
    });
  }

  /// Nombre de ventes référençant cette perruque (pour bloquer la suppression).
  Future<int> ventesLiees(int perruqueId) async {
    final db = await _db;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM ventes WHERE perruqueId = ?',
        [perruqueId]);
    return Sqflite.firstIntValue(r) ?? 0;
  }
}

/// Helper interne pour construire le map d'insertion du mouvement.
class MouvementInsert {
  final int perruqueId;
  final int delta;
  final String type;
  final String? motif;

  const MouvementInsert({
    required this.perruqueId,
    required this.delta,
    required this.type,
    this.motif,
  });

  Map<String, dynamic> toMap() => {
        'perruqueId': perruqueId,
        'delta': delta,
        'type': type,
        'motif': motif,
        'date': DateTime.now().toIso8601String(),
      };
}
