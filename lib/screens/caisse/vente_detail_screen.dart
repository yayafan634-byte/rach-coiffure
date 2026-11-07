import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/vente.dart';
import '../../models/vente_item.dart';
import '../../services/caisse_service.dart';
import '../../services/parametres_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/recu_pdf.dart';
import '../../widgets/app_snack.dart';

class VenteDetailScreen extends StatefulWidget {
  final Vente vente;
  const VenteDetailScreen({super.key, required this.vente});

  @override
  State<VenteDetailScreen> createState() => _VenteDetailScreenState();
}

class _VenteDetailScreenState extends State<VenteDetailScreen> {
  Client? _client;
  List<VenteItem> _items = [];
  Parametres _parametres = const Parametres();
  bool _chargement = true;
  bool _partage = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final vente = widget.vente;
    final db = await DbHelper.instance.db;
    if (vente.clientId != null) {
      final res = await db
          .query('clients', where: 'id = ?', whereArgs: [vente.clientId]);
      if (res.isNotEmpty) _client = Client.fromMap(res.first);
    }

    var items = vente.id == null
        ? <VenteItem>[]
        : await CaisseService.instance.itemsVente(vente.id!);
    if (items.isEmpty) {
      String? nom;
      if (vente.perruqueId != null) {
        final res = await db.query('perruques',
            columns: ['nom'], where: 'id = ?', whereArgs: [vente.perruqueId]);
        if (res.isNotEmpty) nom = res.first['nom'] as String?;
      }
      items = [
        VenteItem(
          venteId: vente.id ?? 0,
          perruqueId: vente.perruqueId,
          libelle: nom ?? vente.libelle ?? 'Vente libre',
          prixUnitaire: vente.quantite > 0 ? vente.montant / vente.quantite : 0,
          quantite: vente.quantite,
          montant: vente.montant,
        ),
      ];
    }

    final params = await ParametresService.instance.charger();
    if (!mounted) return;
    setState(() {
      _items = items;
      _parametres = params;
      _chargement = false;
    });
  }

  Future<void> _partagerPdf() async {
    setState(() => _partage = true);
    try {
      await partagerRecuPdf(
        vente: widget.vente,
        items: _items,
        client: _client,
        parametres: _parametres,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Impossible de partager le reçu PDF.',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _partage = false);
    }
  }

  Future<void> _partagerWhatsApp() async {
    final texte = messageRecuTexte(
      vente: widget.vente,
      items: _items,
      client: _client,
      parametres: _parametres,
    );
    try {
      await Share.share(texte);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Impossible de partager le reçu.',
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vente;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reçu de vente'),
        actions: [
          IconButton(
            tooltip: 'Partager en PDF',
            onPressed: _chargement || _partage ? null : _partagerPdf,
            icon: _partage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Partager le texte',
            onPressed: _chargement ? null : _partagerWhatsApp,
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _parametres.nomSalon,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                      if (_parametres.adresse.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _parametres.adresse,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                      if (_parametres.telephone.trim().isNotEmpty)
                        Text(
                          _parametres.telephone,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'Reçu de caisse',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      _ligne('N°', '#${v.id ?? '-'}'),
                      _ligne('Date', formatDateHeure(v.dateVente)),
                      _ligne('Mode de paiement',
                          _modes[v.modePaiement] ?? v.modePaiement),
                      if (_client != null) ...[
                        const SizedBox(height: 8),
                        _ligne('Client', _client!.nom),
                        _ligne('Téléphone', _client!.telephone),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      ..._items.map(_ligneArticle),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      _ligneMontant('Sous-total', _sousTotal),
                      if (v.remise > 0) _ligneMontant('Remise', -v.remise),
                      if (v.pointsUtilises > 0)
                        _ligneMontant(
                          'Points (${v.pointsUtilises})',
                          -(v.pointsUtilises * _parametres.valeurPoint),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'MONTANT TOTAL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.plum,
                            ),
                          ),
                          Text(
                            formatFcfa(v.montant),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.roseDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _parametres.messageRecu,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _partagerPdf,
                        icon:
                            const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('PDF'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _partagerWhatsApp,
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text('Partager'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  double get _sousTotal => _items.fold<double>(
        0,
        (s, item) => s + item.prixUnitaire * item.quantite,
      );

  Widget _ligneArticle(VenteItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.designation,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.plum,
                  ),
                ),
                Text(
                  '${formatFcfa(item.prixUnitaire)} × ${item.quantite}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatFcfa(item.prixUnitaire * item.quantite),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.plum,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneMontant(String label, double valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Text(
            '${valeur < 0 ? '- ' : ''}${formatFcfa(valeur.abs())}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.plum,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.plum,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _modes = {
  'especes': 'Espèces',
  'orange_money': 'Orange Money',
  'moov_money': 'Moov Money',
  'mix_yas': 'Mix by Yas',
};
