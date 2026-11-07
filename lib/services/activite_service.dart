import '../database/db_helper.dart';

class ActiviteService {
  static final ActiviteService instance = ActiviteService._();
  ActiviteService._();

  Future<void> log({
    required String action,
    String? details,
    String? utilisateur,
    int? userId,
  }) async {
    try {
      final db = await DbHelper.instance.db;
      await db.insert('activites', {
        'userId': userId,
        'utilisateur': utilisateur,
        'action': action,
        'details': details,
        'date': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Le journal ne doit jamais bloquer une action métier.
    }
  }

  Future<void> vider() async {
    final db = await DbHelper.instance.db;
    await db.delete('activites');
  }
}
