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

enum CloudSyncEtat {
  inconnu,
  horsLigne,
  aJour,
  enAttente,
  synchronisation,
  erreur
}

class CloudSyncStatut {
  final CloudSyncEtat etat;
  final DateTime? derniereSync;
  final String message;

  const CloudSyncStatut({
    this.etat = CloudSyncEtat.inconnu,
    this.derniereSync,
    this.message = '',
  });

  CloudSyncStatut copyWith({
    CloudSyncEtat? etat,
    DateTime? derniereSync,
    String? message,
  }) {
    return CloudSyncStatut(
      etat: etat ?? this.etat,
      derniereSync: derniereSync ?? this.derniereSync,
      message: message ?? this.message,
    );
  }
}

class CloudSnapshot {
  final String id;
  final DateTime? date;
  final int poids;
  final bool principal;

  const CloudSnapshot({
    required this.id,
    required this.date,
    required this.poids,
    required this.principal,
  });
}

class CloudSync {
  CloudSync._();

  static final CloudSync instance = CloudSync._();

  static const String _table = 'cloud_sync';
  static const String _id = 'salon';
  static const String _metaHash = 'cloud_hash';
  static const String _metaUpdated = 'cloud_updated_at';
  static const String _metaHistHash = 'cloud_hist_hash';
  static const String _metaHistIndex = 'cloud_hist_index';
  static const int _maxHistorique = 10;
  static const Duration _delaiReseau = Duration(seconds: 8);

  final ValueNotifier<CloudSyncStatut> statut =
      ValueNotifier<CloudSyncStatut>(const CloudSyncStatut());

  SupabaseClient? _client;
  Timer? _auto;
  bool _initLance = false;
  bool _busy = false;
  bool _autoDemarre = false;
  Future<void>? _initFuture;

  bool get actif => _client != null;

  SupabaseClient? get client => _client;

  Future<void> init() => _initFuture ??= _initialiser();

  Future<void> _initialiser() async {
    if (_initLance) return;
    _initLance = true;
    if (!SupabaseConfig.actif) {
      statut.value = const CloudSyncStatut(
        etat: CloudSyncEtat.horsLigne,
        message: 'Synchronisation désactivée.',
      );
      return;
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
    } catch (e) {
      debugPrint('CloudSync init: $e');
      statut.value = const CloudSyncStatut(
        etat: CloudSyncEtat.horsLigne,
        message: 'Cloud indisponible.',
      );
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
      statut.value = const CloudSyncStatut(
        etat: CloudSyncEtat.horsLigne,
        message: 'Synchronisation indisponible.',
      );
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
    statut.value = statut.value.copyWith(
      etat: CloudSyncEtat.synchronisation,
      message: 'Synchronisation en cours...',
    );
    try {
      final local = await BackupService.instance.exporter();
      final hashLocal = _empreinte(local);
      final dernierHash = await _meta(_metaHash);
      final distant = await _telecharger();

      if (distant == null) {
        await _envoyer(local, hashLocal);
        _demarrerAuto();
        _marquerAJour();
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
        await _archiverHistorique(dataDistante, hashDistant, remoteUpdated);
        _demarrerAuto();
        _marquerAJour(date: DateTime.tryParse(remoteUpdated));
        return CloudSyncResult(
          ok: true,
          donneesRecues: true,
          message: '$total élément(s) reçu(s) depuis le cloud.',
        );
      }

      if (localModifie || force) {
        await _envoyer(local, hashLocal);
        _demarrerAuto();
        _marquerAJour();
        return const CloudSyncResult(
          ok: true,
          donneesRecues: false,
          message: 'Données envoyées dans le cloud.',
        );
      }

      _demarrerAuto();
      _marquerAJour(date: DateTime.tryParse(remoteUpdated));
      return const CloudSyncResult(
        ok: true,
        donneesRecues: false,
        message: 'Données déjà à jour.',
      );
    } catch (e) {
      debugPrint('CloudSync synchroniser: $e');
      statut.value = CloudSyncStatut(
        etat: CloudSyncEtat.erreur,
        derniereSync: statut.value.derniereSync,
        message: 'Synchronisation impossible. Vérifiez la connexion.',
      );
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
      if (hashLocal == await _meta(_metaHash)) {
        _marquerAJour(date: DateTime.tryParse(await _meta(_metaUpdated) ?? ''));
        return;
      }
      if (_poids(local) == 0) {
        final distant = await _telecharger();
        if (distant != null && _poids(distant.$1) > 0) {
          statut.value = statut.value.copyWith(
            etat: CloudSyncEtat.enAttente,
            message: 'Le cloud contient des données plus complètes.',
          );
          return;
        }
      }
      await _envoyer(local, hashLocal);
      _marquerAJour();
    } catch (e) {
      debugPrint('CloudSync push: $e');
      statut.value = CloudSyncStatut(
        etat: CloudSyncEtat.enAttente,
        derniereSync: statut.value.derniereSync,
        message: 'Modifications en attente de connexion.',
      );
    }
  }

  void _marquerAJour({DateTime? date}) {
    statut.value = CloudSyncStatut(
      etat: CloudSyncEtat.aJour,
      derniereSync: date ?? DateTime.now(),
      message: 'Données synchronisées.',
    );
  }

  Future<void> rafraichirStatut() async {
    await init();
    if (_client == null) {
      statut.value = const CloudSyncStatut(
        etat: CloudSyncEtat.horsLigne,
        message: 'Cloud indisponible.',
      );
      return;
    }
    try {
      final local = await BackupService.instance.exporter();
      final hashLocal = _empreinte(local);
      final dernierHash = await _meta(_metaHash);
      final derniere = DateTime.tryParse(await _meta(_metaUpdated) ?? '');
      if (hashLocal == dernierHash) {
        statut.value = CloudSyncStatut(
          etat: CloudSyncEtat.aJour,
          derniereSync: derniere,
          message: 'Données synchronisées.',
        );
      } else {
        statut.value = CloudSyncStatut(
          etat: CloudSyncEtat.enAttente,
          derniereSync: derniere,
          message: 'Modifications en attente de synchronisation.',
        );
      }
    } catch (_) {
      statut.value = CloudSyncStatut(
        etat: CloudSyncEtat.enAttente,
        derniereSync: statut.value.derniereSync,
        message: 'Modifications en attente de synchronisation.',
      );
    }
  }

  Future<CloudSyncResult> creerSauvegarde() async {
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
    statut.value = statut.value.copyWith(
      etat: CloudSyncEtat.synchronisation,
      message: 'Sauvegarde en cours...',
    );
    try {
      final local = await BackupService.instance.exporter();
      final hash = _empreinte(local);
      await _envoyer(local, hash, forcerHistorique: true);
      _demarrerAuto();
      _marquerAJour();
      return const CloudSyncResult(
        ok: true,
        donneesRecues: false,
        message: 'Sauvegarde cloud créée.',
      );
    } catch (e) {
      debugPrint('CloudSync creerSauvegarde: $e');
      statut.value = statut.value.copyWith(
        etat: CloudSyncEtat.erreur,
        message: 'Sauvegarde impossible.',
      );
      return const CloudSyncResult(
        ok: false,
        donneesRecues: false,
        message: 'Sauvegarde impossible. Vérifiez la connexion.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<List<CloudSnapshot>> historique() async {
    await init();
    final client = _client;
    if (client == null) return const [];
    try {
      final res = await client
          .from(_table)
          .select('id, payload, updated_at')
          .like('id', 'salon_%')
          .order('updated_at', ascending: false)
          .timeout(_delaiReseau);
      final liste = <CloudSnapshot>[];
      for (final ligne in res) {
        final payload = ligne['payload'];
        if (payload is! String || payload.isEmpty) continue;
        Map<String, dynamic>? data;
        try {
          final decode = jsonDecode(payload);
          if (decode is Map<String, dynamic>) data = decode;
        } catch (_) {}
        if (data == null) continue;
        liste.add(CloudSnapshot(
          id: ligne['id'].toString(),
          date: DateTime.tryParse(ligne['updated_at']?.toString() ?? '')
              ?.toLocal(),
          poids: _poids(data),
          principal: false,
        ));
      }
      return liste;
    } catch (e) {
      debugPrint('CloudSync historique: $e');
      rethrow;
    }
  }

  Future<CloudSyncResult> restaurerSnapshot(String id) async {
    await init();
    final client = _client;
    if (client == null) {
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
    statut.value = statut.value.copyWith(
      etat: CloudSyncEtat.synchronisation,
      message: 'Restauration en cours...',
    );
    try {
      final res = await client
          .from(_table)
          .select('payload, updated_at')
          .eq('id', id)
          .maybeSingle()
          .timeout(_delaiReseau);
      final payload = res?['payload'];
      if (payload is! String || payload.isEmpty) {
        statut.value = statut.value.copyWith(
          etat: CloudSyncEtat.erreur,
          message: 'Sauvegarde introuvable.',
        );
        return const CloudSyncResult(
          ok: false,
          donneesRecues: false,
          message: 'Sauvegarde introuvable.',
        );
      }
      final decode = jsonDecode(payload);
      if (decode is! Map<String, dynamic>) {
        throw const FormatException('Sauvegarde cloud illisible.');
      }
      final hash = _empreinte(decode);
      final total = await BackupService.instance.restaurer(payload);
      await _envoyer(decode, hash);
      _demarrerAuto();
      _marquerAJour();
      return CloudSyncResult(
        ok: true,
        donneesRecues: true,
        message: '$total élément(s) restauré(s) depuis la sauvegarde.',
      );
    } catch (e) {
      debugPrint('CloudSync restaurerSnapshot: $e');
      statut.value = statut.value.copyWith(
        etat: CloudSyncEtat.erreur,
        message: 'Restauration impossible.',
      );
      return const CloudSyncResult(
        ok: false,
        donneesRecues: false,
        message: 'Restauration impossible. Vérifiez la connexion.',
      );
    } finally {
      _busy = false;
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

  Future<void> _envoyer(
    Map<String, dynamic> data,
    String hash, {
    bool forcerHistorique = false,
  }) async {
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
    await _archiverHistorique(
      data,
      hash,
      maintenant,
      forcer: forcerHistorique,
    );
  }

  Future<void> _archiverHistorique(
    Map<String, dynamic> data,
    String hash,
    String maintenant, {
    bool forcer = false,
  }) async {
    final client = _client;
    if (client == null) return;
    if (!forcer && hash == await _meta(_metaHistHash)) return;
    final index = await _prochainIndexHistorique();
    try {
      await client.from(_table).upsert({
        'id': '${_id}_$index',
        'payload': jsonEncode(data),
        'updated_at': maintenant,
      }).timeout(_delaiReseau);
      await _setMeta(_metaHistIndex, '$index');
      await _setMeta(_metaHistHash, hash);
    } catch (e) {
      debugPrint('CloudSync historique: $e');
    }
  }

  Future<int> _prochainIndexHistorique() async {
    final client = _client;
    if (client == null) return 1;
    try {
      final res = await client
          .from(_table)
          .select('id, updated_at')
          .like('id', 'salon_%')
          .timeout(_delaiReseau);
      final utilises = <int, DateTime>{};
      for (final ligne in res) {
        final id = ligne['id']?.toString() ?? '';
        final index = int.tryParse(id.replaceFirst('${_id}_', ''));
        if (index == null || index < 1 || index > _maxHistorique) continue;
        final date = DateTime.tryParse(ligne['updated_at']?.toString() ?? '');
        utilises[index] = date ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      for (var i = 1; i <= _maxHistorique; i++) {
        if (!utilises.containsKey(i)) return i;
      }
      var plusAncien = 1;
      var datePlusAncienne = utilises[1]!;
      for (var i = 2; i <= _maxHistorique; i++) {
        if (utilises[i]!.isBefore(datePlusAncienne)) {
          datePlusAncienne = utilises[i]!;
          plusAncien = i;
        }
      }
      return plusAncien;
    } catch (_) {
      final actuel = int.tryParse(await _meta(_metaHistIndex) ?? '') ?? 0;
      return actuel % _maxHistorique + 1;
    }
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
