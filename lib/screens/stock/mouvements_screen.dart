import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/db_helper.dart';
import '../../models/mouvement_stock.dart';
import '../../theme/app_theme.dart';
import '../../utils/export_pdf.dart';
import '../../widgets/empty_state.dart';

class MouvementsScreen extends StatefulWidget {
  const MouvementsScreen({super.key});

  @override
  State<MouvementsScreen> createState() => _MouvementsScreenState();
}

class _MouvementsScreenState extends State<MouvementsScreen> {
  List<MouvementStock> _mouvements = [];
  bool _chargement = true;
  final _fmt = DateFormat('dd/MM/yy HH:mm');

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final db = await DbHelper.instance.db;
    final res = await db.rawQuery('''
      SELECT m.*, p.nom AS nomPerruque
      FROM mouvements_stock m
      LEFT JOIN perruques p ON p.id = m.perruqueId
      ORDER BY m.date DESC
    ''');
    if (!mounted) return;
    setState(() {
      _mouvements = res.map(MouvementStock.fromMap).toList();
      _chargement = false;
    });
  }

  Future<void> _exporterPdf() async {
    final lignes = _mouvements
        .map((m) => [
              _fmt.format(m.date),
              m.nomPerruque,
              _libelleType(m.type),
              '${m.delta > 0 ? '+' : ''}${m.delta}',
              m.motif ?? '',
            ])
        .toList();
    await exporterRapportPdf(
      titre: 'Historique mouvements stock',
      sousTitre: 'Entrées: +${_mouvements.where((m) => m.delta > 0).fold<int>(0, (s, m) => s + m.delta)} | Sorties: ${_mouvements.where((m) => m.delta < 0).fold<int>(0, (s, m) => s + m.delta.abs())}',
      entetes: const ['Date/Heure', 'Article', 'Type', 'Qté', 'Motif'],
      lignes: lignes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entrees = _mouvements
        .where((m) => m.delta > 0)
        .fold<int>(0, (s, m) => s + m.delta);
    final sorties = _mouvements
        .where((m) => m.delta < 0)
        .fold<int>(0, (s, m) => s + m.delta.abs());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique du stock'),
        actions: [
          IconButton(
            tooltip: 'Exporter en PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _mouvements.isEmpty ? null : _exporterPdf,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _mouvements.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Aucun mouvement',
                  message:
                      'Les entrées et sorties de stock apparaîtront ici.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _resume(
                              icon: Icons.arrow_downward_rounded,
                              label: 'Entrées',
                              valeur: '+$entrees',
                              accent: AppColors.success,
                              fond: AppColors.successSoft,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _resume(
                              icon: Icons.arrow_upward_rounded,
                              label: 'Sorties',
                              valeur: '-$sorties',
                              accent: AppColors.danger,
                              fond: AppColors.dangerSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _charger,
                        color: AppColors.rose,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          itemCount: _mouvements.length,
                          itemBuilder: (ctx, i) =>
                              _carteMouvement(_mouvements[i]),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _resume({
    required IconData icon,
    required String label,
    required String valeur,
    required Color accent,
    required Color fond,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: fond,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valeur,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteMouvement(MouvementStock m) {
    final entree = m.estEntree;
    final accent = entree ? AppColors.success : AppColors.danger;
    final fond = entree ? AppColors.successSoft : AppColors.dangerSoft;
    final motif = m.motif?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fond,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                entree
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 20,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entree ? '+' : ''}${m.delta} • ${m.nomPerruque}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.plum,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _libelleType(m.type),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  if (motif != null && motif.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      motif,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('HH:mm').format(m.date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy').format(m.date),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _libelleType(String t) => switch (t) {
        'entree' => 'Entrée',
        'sortie' => 'Sortie',
        _ => 'Ajustement',
      };
}
