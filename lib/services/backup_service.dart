import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  static const _tables = [
    'users',
    'perruques',
    'clients',
    'prestations',
    'rendezVous',
    'ventes',
    'venteItems',
    'mouvements_stock',
    'depenses',
    'activites',
    'parametres',
  ];

  static const _ordreSuppression = [
    'venteItems',
    'ventes',
    'mouvements_stock',
    'rendezVous',
    'perruques',
    'prestations',
    'clients',
    'depenses',
    'activites',
    'parametres',
    'users',
  ];

  Future<Map<String, dynamic>> exporter() async {
    final db = await DbHelper.instance.db;
    final donnees = <String, dynamic>{};
    for (final table in _tables) {
      donnees[table] = await db.query(table);
    }
    return {
      'application': 'rach_coiffure',
      'version': 1,
      'genereLe': DateTime.now().toIso8601String(),
      'tables': donnees,
    };
  }

  Future<String> exporterJson() async {
    final donnees = await exporter();
    return const JsonEncoder.withIndent('  ').convert(donnees);
  }

  Future<int> restaurer(String contenu) async {
    final decode = jsonDecode(contenu);
    if (decode is! Map<String, dynamic> ||
        decode['application'] != 'rach_coiffure' ||
        decode['tables'] is! Map<String, dynamic>) {
      throw const FormatException('Fichier de sauvegarde invalide.');
    }

    final tables = decode['tables'] as Map<String, dynamic>;
    final users = tables['users'];
    if (users is! List || users.isEmpty) {
      throw const FormatException(
        'Sauvegarde invalide : aucun compte utilisateur.',
      );
    }
    final contientAdmin = users.any((u) {
      if (u is! Map) return false;
      final hash = u['motDePasseHash'];
      return u['role'] == 'admin' && hash is String && hash.isNotEmpty;
    });
    if (!contientAdmin) {
      throw const FormatException(
        'Sauvegarde invalide : aucun administrateur actif.',
      );
    }

    final db = await DbHelper.instance.db;
    var total = 0;

    await db.transaction((txn) async {
      for (final table in _ordreSuppression) {
        await txn.delete(table);
      }
      for (final table in _tables) {
        final lignes = tables[table];
        if (lignes is! List) continue;
        for (final ligne in lignes) {
          if (ligne is! Map) continue;
          final map = Map<String, dynamic>.from(ligne);
          await txn.insert(
            table,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          total++;
        }
      }
    });

    return total;
  }
}
