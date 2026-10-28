import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/section_header.dart';

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

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final db = await DbHelper.instance.db;
    final ventesRes = await db.rawQuery('''
      SELECT v.*, p.nom AS nomPerruque
      FROM ventes v LEFT JOIN perruques p ON p.id = v.perruqueId
      WHERE v.clientId = ?
      ORDER BY v.dateVente DESC
    ''', [widget.client.id]);
    final rdvRes = await db.rawQuery('''
      SELECT r.*, pr.nom AS nomPrestation
      FROM rendezVous r LEFT JOIN prestations pr ON pr.id = r.prestationId
      WHERE r.clientId = ?
      ORDER BY r.dateHeure DESC
    ''', [widget.client.id]);

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

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return Scaffold(
      appBar: AppBar(title: Text(c.nom)),
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
          _avatar(c, 56),
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
    final nom = (v['nomPerruque'] as String?)?.isNotEmpty == true
        ? v['nomPerruque']
        : 'Vente libre';
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fond,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statut,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
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

  Widget _avatar(Client c, double taille) {
    final palettes = [
      (AppColors.roseDeep, AppColors.roseSoft),
      (AppColors.gold, AppColors.goldSoft),
      (AppColors.success, AppColors.successSoft),
      (const Color(0xFF5F7A9B), const Color(0xFFE7EEF6)),
      (const Color(0xFF6A4C93), const Color(0xFFEFE8F7)),
    ];
    final index = c.nom.isEmpty ? 0 : c.nom.codeUnitAt(0) % palettes.length;
    final (accent, fond) = palettes[index];

    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
      child: Text(
        initiales(c.nom),
        style: TextStyle(
          fontSize: taille * 0.34,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}
