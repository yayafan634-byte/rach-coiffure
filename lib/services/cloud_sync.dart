import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../database/db_helper.dart';
import 'backup_service.dart';

class CloudSyncResult {
  final bool ok;
  final bool donneesRecues;
  final String message;

  const CloudSyncResult({
    required this.ok,
    required this.donneesRecues,
    required this.message,
  });
}

class CloudSync {
  CloudSync._();

  static final CloudSync instance = CloudSync._();

  static const String _table = 'cloud_sync';
  static const String _id = 'salon';
  static const String _metaHash = 'cloud_hash';
  static const String _metaUpdated = 'cloud_updated_at';
  static const Duration _delaiReseau = Duration(seconds: 8);

  SupabaseClient? _client;
  Timer? _auto;
  bool _initLance = false;
  bool _busy = false;
  bool _autoDemarre = false;
  Future<void>? _initFuture;

  bool get actif => _client != null;

  Future<void> init() => _initFuture ??= _initialiser();

  Future<void> _initialiser() async {
    if (_initLance) return;
    _initLance = true;
    if (!SupabaseConfig.actif) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
    } catch (e) {
      debugPrint('CloudSync init: $e');
    }
  }

  void _demarrerAuto() {
    if (_autoDemarre || _client == null) return;
    _autoDemarre = true;
    _auto = Timer.periodic(
      const Duration(seconds: 20),
      (_) => pushMaintenant(),
    );
  }

  void arreter() {
    _auto?.cancel();
    _auto = null;
    _autoDemarre = false;
  }

  Future<CloudSyncResult> synchroniser({bool force = false}) async {
    await init();
    if (_client == null) {
      return const CloudSyncResult(
        ok: false,
        donneesRecues: false,
        message: 'Synchronisation indisponible.',
      );
    }
    if (_busy) {
      return const CloudSyncResult(
        ok: false,
        donneesRecues: false,
        message: 'Synchronisation déjà en cours.',
      );
    }

    _busy = true;
    try {
      final local = await BackupService.instance.exporter();
      final hashLocal = _empreinte(local);
      final dernierHash = await _meta(_metaHash);
      final distant = await _telecharger();

      if (distant == null) {
        await _envoyer(local, hashLocal);
        _demarrerAuto();
        return const CloudSyncResult(
          ok: true,
          donneesRecues: false,
          message: 'Données envoyées dans le cloud.',
        );
      }

      final dataDistante = distant.$1;
      final hashDistant = _empreinte(dataDistante);
      final remoteUpdated = distant.$2;
      final localModifie = hashLocal != dernierHash;
      final poidsLocal = _poids(local);
      final poidsDistant = _poids(dataDistante);
      final premierSync = dernierHash == null;

      final distantPlusRiche = hashDistant != hashLocal &&
          ((premierSync && poidsDistant > poidsLocal) ||
              !localModifie ||
              (poidsLocal == 0 && poidsDistant > 0));

      if (distantPlusRiche) {
        final total =
            await BackupService.instance.restaurer(jsonEncode(dataDistante));
        await _setMeta(_metaHash, hashDistant);
        await _setMeta(_metaUpdated, remoteUpdated);
        _demarrerAuto();
        return CloudSyncResult(
          ok: true,
          donneesRecues: true,
          message: '$total élément(s) reçu(s) depuis le cloud.',
        );
      }

      if (localModifie || force) {
        await _envoyer(local, hashLocal);
        _demarrerAuto();
        return const CloudSyncResult(
          ok: true,
          donneesRecues: false,
          message: 'Données envoyées dans le cloud.',
        );
      }

      _demarrerAuto();
      return const CloudSyncResult(
        ok: true,
        donneesRecues: false,
        message: 'Données déjà à jour.',
      );
    } catch (e) {
      debugPrint('CloudSync synchroniser: $e');
      return const CloudSyncResult(
        ok: false,
        donneesRecues: false,
        message: 'Synchronisation impossible. Vérifiez la connexion '
            'ou le script Supabase.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> pushMaintenant() async {
    await init();
    if (_client == null) return;
    try {
      final local = await BackupService.instance.exporter();
      final hashLocal = _empreinte(local);
      if (hashLocal == await _meta(_metaHash)) return;
      if (_poids(local) == 0) {
        final distant = await _telecharger();
        if (distant != null && _poids(distant.$1) > 0) return;
      }
      await _envoyer(local, hashLocal);
    } catch (e) {
      debugPrint('CloudSync push: $e');
    }
  }

  Future<(Map<String, dynamic>, String)?> _telecharger() async {
    final client = _client;
    if (client == null) return null;
    final res = await client
        .from(_table)
        .select('payload, updated_at')
        .eq('id', _id)
        .maybeSingle()
        .timeout(_delaiReseau);
    if (res == null) return null;
    final payload = res['payload'];
    if (payload is! String || payload.isEmpty) return null;
    final decode = jsonDecode(payload);
    if (decode is! Map<String, dynamic>) return null;
    return (decode, res['updated_at']?.toString() ?? '');
  }

  Future<void> _envoyer(Map<String, dynamic> data, String hash) async {
    final client = _client;
    if (client == null) return;
    final maintenant = DateTime.now().toUtc().toIso8601String();
    await client.from(_table).upsert({
      'id': _id,
      'payload': jsonEncode(data),
      'updated_at': maintenant,
    }).timeout(_delaiReseau);
    await _setMeta(_metaHash, hash);
    await _setMeta(_metaUpdated, maintenant);
  }

  Future<String?> _meta(String cle) async {
    final db = await DbHelper.instance.db;
    final res = await db.query(
      'sync_meta',
      where: 'cle = ?',
      whereArgs: [cle],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['valeur'] as String?;
  }

  Future<void> _setMeta(String cle, String valeur) async {
    final db = await DbHelper.instance.db;
    await db.insert(
      'sync_meta',
      {'cle': cle, 'valeur': valeur},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  int _poids(Map<String, dynamic> data) {
    final tables = data['tables'];
    if (tables is! Map) return 0;
    var total = 0;
    for (final cle in const [
      'perruques',
      'clients',
      'ventes',
      'venteItems',
      'mouvements_stock',
      'depenses',
      'rendezVous',
    ]) {
      final lignes = tables[cle];
      if (lignes is List) total += lignes.length;
    }
    return total;
  }

  String _empreinte(Map<String, dynamic> data) {
    final tampon = StringBuffer();
    final tables = data['tables'];
    if (tables is Map) {
      final noms = tables.keys.map((e) => e.toString()).toList()..sort();
      for (final nom in noms) {
        tampon.write(nom);
        final lignes = tables[nom];
        if (lignes is List) {
          final maps = lignes
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
            ..sort((a, b) => _idDe(a).compareTo(_idDe(b)));
          for (final ligne in maps) {
            final cles = ligne.keys.toList()..sort();
            tampon.write('|');
            for (final cle in cles) {
              tampon.write('$cle=${ligne[cle]};');
            }
          }
        }
        tampon.write('\n');
      }
    }
    return sha256.convert(utf8.encode(tampon.toString())).toString();
  }

  String _idDe(Map<String, dynamic> ligne) {
    final id = ligne['id'];
    if (id is num) return id.toString().padLeft(12, '0');
    return id?.toString() ?? '';
  }
}
