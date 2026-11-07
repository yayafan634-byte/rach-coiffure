import '../database/db_helper.dart';
import '../models/vente.dart';
import '../models/vente_item.dart';

class LignePanier {
  final int? perruqueId;
  final String libelle;
  final double prixUnitaire;
  final int quantite;

  const LignePanier({
    this.perruqueId,
    required this.libelle,
    required this.prixUnitaire,
    this.quantite = 1,
  });

  double get total => prixUnitaire * quantite;

  LignePanier copyWith({int? quantite}) => LignePanier(
        perruqueId: perruqueId,
        libelle: libelle,
        prixUnitaire: prixUnitaire,
        quantite: quantite ?? this.quantite,
      );
}

class CaisseException implements Exception {
  final String message;
  const CaisseException(this.message);

  @override
  String toString() => message;
}

class CaisseService {
  static final CaisseService instance = CaisseService._();
  CaisseService._();

  static const pointsParMillier = 1;

  double _arrondi(double valeur) => (valeur * 100).round() / 100;

  Future<Vente> vendre({
    required List<LignePanier> lignes,
    required String modePaiement,
    int? clientId,
    double remise = 0,
    int pointsUtilises = 0,
    double valeurPoint = 100,
    int? userId,
    String? utilisateur,
  }) async {
    if (lignes.isEmpty) throw const CaisseException('Le panier est vide.');
    if (remise < 0) throw const CaisseException('Remise invalide.');
    if (pointsUtilises < 0) {
      throw const CaisseException('Nombre de points invalide.');
    }
    if (pointsUtilises > 0 && clientId == null) {
      throw const CaisseException(
          'Sélectionnez un client pour utiliser ses points.');
    }

    final sousTotal = _arrondi(
      lignes.fold<double>(0, (s, l) => s + l.total),
    );
    if (sousTotal <= 0) {
      throw const CaisseException('Le montant de la vente est nul.');
    }
    if (remise > sousTotal) {
      throw const CaisseException('La remise dépasse le sous-total.');
    }

    final pointsRemise = _arrondi(pointsUtilises * valeurPoint);
    final net = _arrondi(sousTotal - remise - pointsRemise);
    if (net < 0) {
      throw const CaisseException('Les points utilisés dépassent le total.');
    }

    final db = await DbHelper.instance.db;
    return db.transaction<Vente>((txn) async {
      final quantites = <int, int>{};
      for (final ligne in lignes) {
        final id = ligne.perruqueId;
        if (id == null) continue;
        if (ligne.quantite <= 0) {
          throw const CaisseException('Quantité invalide.');
        }
        quantites[id] = (quantites[id] ?? 0) + ligne.quantite;
      }

      for (final e in quantites.entries) {
        final res = await txn.query(
          'perruques',
          columns: ['quantite', 'nom'],
          where: 'id = ?',
          whereArgs: [e.key],
        );
        if (res.isEmpty) {
          throw const CaisseException('Article introuvable.');
        }
        final dispo = (res.first['quantite'] as num).toInt();
        if (dispo < e.value) {
          throw CaisseException(
            'Stock insuffisant pour ${res.first['nom']} '
            '(disponible : $dispo).',
          );
        }
      }

      var pointsClient = 0;
      if (clientId != null) {
        final res = await txn.query(
          'clients',
          columns: ['pointsFidelite', 'nom'],
          where: 'id = ?',
          whereArgs: [clientId],
        );
        if (res.isEmpty) throw const CaisseException('Client introuvable.');
        pointsClient = (res.first['pointsFidelite'] as num).toInt();
        if (pointsUtilises > pointsClient) {
          throw CaisseException(
              'Le client ne possède que $pointsClient point(s).');
        }
      }

      final totalQuantite = lignes.fold<int>(0, (s, l) => s + l.quantite);
      final uniquePerruque =
          lignes.length == 1 ? lignes.first.perruqueId : null;
      final venteId = await txn.insert('ventes', {
        if (clientId != null) 'clientId': clientId,
        if (uniquePerruque != null) 'perruqueId': uniquePerruque,
        if (lignes.length == 1) 'libelle': lignes.first.libelle,
        'montant': net,
        'quantite': totalQuantite,
        'modePaiement': modePaiement,
        'remise': remise,
        'pointsUtilises': pointsUtilises,
        'dateVente': DateTime.now().toIso8601String(),
      });

      final ratio = sousTotal == 0 ? 0.0 : net / sousTotal;
      var cumul = 0.0;
      for (var i = 0; i < lignes.length; i++) {
        final ligne = lignes[i];
        final montant = i == lignes.length - 1
            ? _arrondi(net - cumul)
            : _arrondi(ligne.total * ratio);
        cumul = _arrondi(cumul + montant);
        await txn.insert('venteItems', {
          'venteId': venteId,
          if (ligne.perruqueId != null) 'perruqueId': ligne.perruqueId,
          'libelle': ligne.libelle,
          'prixUnitaire': ligne.prixUnitaire,
          'quantite': ligne.quantite,
          'montant': montant,
        });
      }

      final date = DateTime.now().toIso8601String();
      for (final e in quantites.entries) {
        await txn.rawUpdate(
          'UPDATE perruques SET quantite = quantite - ? WHERE id = ?',
          [e.value, e.key],
        );
        await txn.insert('mouvements_stock', {
          'perruqueId': e.key,
          'delta': -e.value,
          'type': 'sortie',
          'motif': 'Vente #$venteId',
          'date': date,
        });
      }

      if (clientId != null) {
        final gagnes = (net / 1000).floor() * pointsParMillier;
        final nouveaux = pointsClient - pointsUtilises + gagnes;
        await txn.update(
          'clients',
          {'pointsFidelite': nouveaux < 0 ? 0 : nouveaux},
          where: 'id = ?',
          whereArgs: [clientId],
        );
      }

      await txn.insert('activites', {
        'userId': userId,
        'utilisateur': utilisateur,
        'action': 'Vente encaissée',
        'details':
            'Vente #$venteId • ${lignes.length} ligne(s) • $net FCFA • $modePaiement',
        'date': date,
      });

      return Vente(
        id: venteId,
        clientId: clientId,
        perruqueId: uniquePerruque,
        montant: net,
        quantite: totalQuantite,
        modePaiement: modePaiement,
        libelle: lignes.length == 1 ? lignes.first.libelle : null,
        remise: remise,
        pointsUtilises: pointsUtilises,
        dateVente: DateTime.now(),
      );
    });
  }

  Future<List<VenteItem>> itemsVente(int venteId) async {
    final db = await DbHelper.instance.db;
    final res = await db.rawQuery('''
      SELECT vi.*, p.nom AS nomPerruque
      FROM venteItems vi
      LEFT JOIN perruques p ON p.id = vi.perruqueId
      WHERE vi.venteId = ?
      ORDER BY vi.id ASC
    ''', [venteId]);
    return res.map((m) {
      final nom = (m['nomPerruque'] as String?)?.trim();
      return VenteItem.fromMap({
        ...m,
        'libelle': nom == null || nom.isEmpty ? (m['libelle'] as String?) : nom,
      });
    }).toList();
  }
}
