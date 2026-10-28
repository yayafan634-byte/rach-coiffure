import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/user.dart';
import '../utils/hash.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<String?> login(String telephone, String motDePasse) async {
    final db = await DbHelper.instance.db;
    final res = await db.query(
      'users',
      where: 'telephone = ? AND actif = 1',
      whereArgs: [telephone],
    );
    if (res.isEmpty) return 'Utilisateur non trouvé ou inactif';

    final u = AppUser.fromMap(res.first);
    if (!verifyPassword(motDePasse, u.motDePasseHash)) {
      return 'Mot de passe incorrect';
    }
    // Upgrade legacy SHA-256 hash to bcrypt on successful login
    if (isLegacyHash(u.motDePasseHash)) {
      try {
        await db.update(
          'users',
          {'motDePasseHash': hashPassword(motDePasse)},
          where: 'id = ?',
          whereArgs: [u.id],
        );
      } catch (_) {}
    }
    _user = u;
    notifyListeners();
    return null;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  Future<void> creerPremierAdmin() async {
    final db = await DbHelper.instance.db;
    final res = await db.query('users', where: 'role = ?', whereArgs: ['admin']);
    if (res.isNotEmpty) return;

    await db.insert(
        'users',
        AppUser(
          nom: 'Administrateur',
          telephone: '0000',
          motDePasseHash: hashPassword('admin123'),
          role: 'admin',
        ).toMap());
  }
}
