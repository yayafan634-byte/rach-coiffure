import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/user.dart';
import '../services/activite_service.dart';
import '../utils/hash.dart';
import '../utils/id.dart';

/// Règles minimales appliquées à tout nouveau mot de passe.
String? validerMotDePasse(String motDePasse) {
  if (motDePasse.length < 8) return 'Minimum 8 caractères';
  if (!RegExp(r'[A-Za-z]').hasMatch(motDePasse) ||
      !RegExp(r'[0-9]').hasMatch(motDePasse)) {
    return 'Utilisez au moins une lettre et un chiffre';
  }
  return null;
}

class _Tentatives {
  int echecs = 0;
  DateTime? bloqueJusqua;
}

class AuthProvider extends ChangeNotifier {
  static const int _maxTentatives = 5;
  static const Duration _dureeBlocage = Duration(minutes: 5);
  static const String _cleSession = 'session_user_id';
  final Map<String, _Tentatives> _tentatives = {};

  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get doitChangerMotDePasse => _user?.doitChangerMotDePasse ?? false;

  Set<String> get permissions => _user?.permissions ?? const {};
  bool peut(String cle) => _user?.peut(cle) ?? false;

  Future<void> chargerSession() async {
    try {
      final db = await DbHelper.instance.db;
      final res = await db.query(
        'sync_meta',
        where: 'cle = ?',
        whereArgs: [_cleSession],
        limit: 1,
      );
      if (res.isEmpty) return;
      final id = int.tryParse(res.first['valeur']?.toString() ?? '');
      if (id == null) {
        await _supprimerSession();
        return;
      }
      final users = await db.query(
        'users',
        where: 'id = ? AND actif = 1',
        whereArgs: [id],
        limit: 1,
      );
      if (users.isEmpty) {
        await _supprimerSession();
        return;
      }
      _user = AppUser.fromMap(users.first);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _enregistrerSession(int? userId) async {
    if (userId == null) return;
    try {
      final db = await DbHelper.instance.db;
      await db.insert(
        'sync_meta',
        {'cle': _cleSession, 'valeur': '$userId'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> _supprimerSession() async {
    try {
      final db = await DbHelper.instance.db;
      await db.delete(
        'sync_meta',
        where: 'cle = ?',
        whereArgs: [_cleSession],
      );
    } catch (_) {}
  }

  Future<String?> login(String telephone, String motDePasse) async {
    final cle = telephone.trim().toLowerCase();
    final maintenant = DateTime.now();
    final tentatives = _tentatives[cle];
    if (tentatives?.bloqueJusqua != null &&
        maintenant.isBefore(tentatives!.bloqueJusqua!)) {
      final restant =
          tentatives.bloqueJusqua!.difference(maintenant).inMinutes + 1;
      return 'Trop de tentatives. Réessayez dans $restant min.';
    }

    final db = await DbHelper.instance.db;
    final res = await db.query(
      'users',
      where: 'telephone = ? AND actif = 1',
      whereArgs: [telephone],
    );
    if (res.isEmpty) {
      _enregistrerEchec(cle);
      await ActiviteService.instance.log(
        action: 'Connexion refusée',
        details: 'Numéro inconnu ou compte inactif : $telephone',
      );
      return 'Utilisateur non trouvé ou inactif';
    }

    final u = AppUser.fromMap(res.first);
    if (!verifyPassword(motDePasse, u.motDePasseHash)) {
      final message = _enregistrerEchec(cle);
      await ActiviteService.instance.log(
        action: 'Connexion refusée',
        details: 'Mot de passe incorrect pour ${u.nom}',
        utilisateur: u.nom,
        userId: u.id,
      );
      return message ?? 'Mot de passe incorrect';
    }
    _tentatives.remove(cle);
    var utilisateur = u;
    // Upgrade legacy SHA-256 hash to bcrypt on successful login
    if (isLegacyHash(u.motDePasseHash)) {
      try {
        final hash = hashPassword(motDePasse);
        await db.update(
          'users',
          {'motDePasseHash': hash},
          where: 'id = ?',
          whereArgs: [u.id],
        );
        utilisateur = u.copyWith(motDePasseHash: hash);
      } catch (_) {}
    }
    _user = utilisateur;
    await _enregistrerSession(utilisateur.id);
    await ActiviteService.instance.log(
      action: 'Connexion',
      details:
          'Session ouverte (${u.isAdmin ? 'administrateur' : 'gestionnaire'})',
      utilisateur: u.nom,
      userId: u.id,
    );
    notifyListeners();
    return null;
  }

  String? _enregistrerEchec(String cle) {
    final t = _tentatives.putIfAbsent(cle, () => _Tentatives());
    t.echecs++;
    if (t.echecs >= _maxTentatives) {
      t.echecs = 0;
      t.bloqueJusqua = DateTime.now().add(_dureeBlocage);
      return 'Trop de tentatives. Réessayez dans 5 min.';
    }
    final restantes = _maxTentatives - t.echecs;
    return 'Mot de passe incorrect ($restantes tentative(s) restante(s))';
  }

  Future<String?> changerMotDePasse({
    required String actuel,
    required String nouveau,
    bool verifierActuel = true,
  }) async {
    final u = _user;
    if (u == null) return 'Aucune session active';
    if (verifierActuel && !verifyPassword(actuel, u.motDePasseHash)) {
      return 'Mot de passe actuel incorrect';
    }
    final erreur = validerMotDePasse(nouveau);
    if (erreur != null) return erreur;
    if (verifyPassword(nouveau, u.motDePasseHash)) {
      return 'Le nouveau mot de passe doit être différent de l\'ancien';
    }

    final db = await DbHelper.instance.db;
    final hash = hashPassword(nouveau);
    await db.update(
      'users',
      {'motDePasseHash': hash, 'doitChangerMotDePasse': 0},
      where: 'id = ?',
      whereArgs: [u.id],
    );
    _user = u.copyWith(motDePasseHash: hash, doitChangerMotDePasse: false);
    await ActiviteService.instance.log(
      action: 'Mot de passe modifié',
      details: 'Mot de passe du compte mis à jour',
      utilisateur: u.nom,
      userId: u.id,
    );
    notifyListeners();
    return null;
  }

  Future<String?> reinitialiserMotDePasse(int userId, String nouveau) async {
    final admin = _user;
    if (!isAdmin) return 'Action réservée à l\'administrateur';
    final erreur = validerMotDePasse(nouveau);
    if (erreur != null) return erreur;

    final db = await DbHelper.instance.db;
    final res = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (res.isEmpty) return 'Utilisateur introuvable';
    final cible = AppUser.fromMap(res.first);

    await db.update(
      'users',
      {
        'motDePasseHash': hashPassword(nouveau),
        'doitChangerMotDePasse': 1,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
    await ActiviteService.instance.log(
      action: 'Mot de passe réinitialisé',
      details: '${cible.nom} • ${cible.telephone}',
      utilisateur: admin?.nom,
      userId: admin?.id,
    );
    return null;
  }

  Future<void> logout() async {
    final u = _user;
    if (u != null) {
      await ActiviteService.instance.log(
        action: 'Déconnexion',
        details: 'Session fermée',
        utilisateur: u.nom,
        userId: u.id,
      );
    }
    _user = null;
    await _supprimerSession();
    notifyListeners();
  }

  Future<void> creerPremierAdmin() async {
    final db = await DbHelper.instance.db;
    final res =
        await db.query('users', where: 'role = ?', whereArgs: ['admin']);
    if (res.isNotEmpty) {
      // Les installations existantes créées avec le mot de passe par défaut
      // doivent le changer dès la prochaine connexion.
      for (final row in res) {
        final u = AppUser.fromMap(row);
        if (u.id == null || u.doitChangerMotDePasse) continue;
        if (verifyPassword('admin123', u.motDePasseHash)) {
          await db.update(
            'users',
            {'doitChangerMotDePasse': 1},
            where: 'id = ?',
            whereArgs: [u.id],
          );
        }
      }
      return;
    }

    final map = AppUser(
      nom: 'Issiaka',
      telephone: '0000',
      motDePasseHash: hashPassword('admin123'),
      role: 'admin',
      doitChangerMotDePasse: true,
    ).toMap();
    map['id'] = nouvelId();
    await db.insert('users', map);
    await ActiviteService.instance.log(
      action: 'Compte administrateur initial créé',
      details: 'Compte par défaut « Issiaka » (0000)',
      utilisateur: 'Issiaka',
    );
  }
}
