import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/journal.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import 'client_form_sheet.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<Map<String, dynamic>> _ventes = [];
  List<Map<String, dynamic>> _rdvs = [];
  double _totalDepense = 0;
  bool _chargement = true;
  late Client _client;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _charger();
  }

  Future<void> _charger() async {
    final db = await DbHelper.instance.db;
    final ventesRes = await db.rawQuery('''
      SELECT v.*, p.nom AS nomPerruque
      FROM ventes v LEFT JOIN perruques p ON p.id = v.perruqueId
      WHERE v.clientId = ?
      ORDER BY v.dateVente DESC
    ''', [_client.id]);
    final rdvRes = await db.rawQuery('''
      SELECT r.*, pr.nom AS nomPrestation
      FROM rendezVous r LEFT JOIN prestations pr ON pr.id = r.prestationId
      WHERE r.clientId = ?
      ORDER BY r.dateHeure DESC
    ''', [_client.id]);

    double total = 0;
    for (final v in ventesRes) {
      total += (v['montant'] as num).toDouble();
    }

    if (!mounted) return;
    setState(() {
      _ventes = ventesRes;
      _rdvs = rdvRes;
      _totalDepense = total;
      _chargement = false;
    });
  }

  Future<void> _modifier() async {
    final modifie = await showClientFormSheet(context, client: _client);
    if (!modifie || !mounted) return;
    final db = await DbHelper.instance.db;
    final res = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [_client.id],
    );
    if (!mounted) return;
    if (res.isNotEmpty) {
      setState(() => _client = Client.fromMap(res.first));
    }
    _charger();
  }

  Future<void> _supprimer() async {
    final auth = context.read<AuthProvider>();
    if (!auth.peut('suppressions')) return;

    final db = await DbHelper.instance.db;
    final ventes = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ventes WHERE clientId = ?',
      [_client.id],
    );
    final rdvs = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM rendezVous WHERE clientId = ?',
      [_client.id],
    );
    final nbVentes = (ventes.first['n'] as num?)?.toInt() ?? 0;
    final nbRdvs = (rdvs.first['n'] as num?)?.toInt() ?? 0;
    if (!mounted) return;

    if (nbVentes > 0 || nbRdvs > 0) {
      showAppSnack(
        context,
        'Impossible de supprimer : $nbVentes vente(s) et '
        '$nbRdvs rendez-vous liés à ce client.',
        type: AppSnackType.error,
      );
      return;
    }

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${_client.nom} ?'),
        content: const Text(
          'La fiche client sera définitivement supprimée. '
          'Cette opération est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmer != true || !mounted) return;

    await db.delete('clients', where: 'id = ?', whereArgs: [_client.id]);
    if (!mounted) return;
    await journaliser(
      context,
      'Client supprimé',
      details: '${_client.nom} • ${_client.telephone}',
    );
    if (!mounted) return;
    showAppSnack(
      context,
      'Client supprimé.',
      type: AppSnackType.success,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = _client;
    final peutSupprimer = context.watch<AuthProvider>().peut('suppressions');
    return Scaffold(
      appBar: AppBar(
        title: Text(c.nom),
        actions: [
          IconButton(
            tooltip: 'Modifier le client',
            onPressed: _modifier,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (peutSupprimer)
            IconButton(
              tooltip: 'Supprimer le client',
              onPressed: _supprimer,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _entete(c),
                  const SizedBox(height: 16),
                  _stats(c),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Achats'),
                  const SizedBox(height: 8),
                  if (_ventes.isEmpty)
                    _vide('Aucun achat enregistré')
                  else
                    ..._ventes.map(_carteVente),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Rendez-vous'),
                  const SizedBox(height: 8),
                  if (_rdvs.isEmpty)
                    _vide('Aucun rendez-vous')
                  else
                    ..._rdvs.map(_carteRdv),
                ],
              ),
            ),
    );
  }

  Widget _entete(Client c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          InitialsAvatar(name: c.nom, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.nom,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.plum,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.telephone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
                if (c.adresse != null && c.adresse!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    c.adresse!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(Client c) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.payments_outlined,
            label: 'Total dépensé',
            value: formatFcfa(_totalDepense),
            color: AppColors.success,
            bg: AppColors.successSoft,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            icon: Icons.stars_rounded,
            label: 'Points fidélité',
            value: '${c.pointsFidelite}',
            color: AppColors.gold,
            bg: AppColors.goldSoft,
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.plum,
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteVente(Map<String, dynamic> v) {
    final libelle = (v['libelle'] as String?)?.trim();
    final nom = (v['nomPerruque'] as String?)?.isNotEmpty == true
        ? v['nomPerruque']
        : (libelle != null && libelle.isNotEmpty ? libelle : 'Vente libre');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.roseDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.plum,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(v['dateVente'])} • ${formatHeure(v['dateVente'])}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatFcfa((v['montant'] as num).toDouble()),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.plum,
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteRdv(Map<String, dynamic> r) {
    final statut = (r['statut'] as String?) ?? 'prévu';
    final (accent, fond) = switch (statut) {
      'terminé' => (AppColors.success, AppColors.successSoft),
      'annulé' => (AppColors.danger, AppColors.dangerSoft),
      _ => (AppColors.warning, AppColors.warningSoft),
    };
    final libelleStatut = statut.isEmpty
        ? statut
        : '${statut[0].toUpperCase()}${statut.substring(1)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.roseSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  formatHeure(r['dateHeure']),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.roseDeep,
                  ),
                ),
                Text(
                  formatDate(r['dateHeure']),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.roseDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (r['nomPrestation'] as String?)?.isNotEmpty == true
                  ? r['nomPrestation']
                  : 'Sans prestation',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.plum,
              ),
            ),
          ),
          StatusPill(label: libelleStatut, color: accent, background: fond),
        ],
      ),
    );
  }

  Widget _vide(String texte) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        texte,
        style: const TextStyle(
          fontSize: 12.5,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
