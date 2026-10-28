import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/perruque.dart';
import '../../theme/app_theme.dart';
import '../../utils/export_csv.dart';
import '../../utils/export_pdf.dart';
import '../../utils/format.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  double _caJour = 0;
  double _caMois = 0;
  int _nbVentesJour = 0;
  int _nbVentesMois = 0;
  double _valeurStockAchat = 0;
  double _margeVendue = 0;
  List<Map<String, dynamic>> _bestSellers = [];
  List<Perruque> _alertes = [];
  List<Map<String, dynamic>> _ventes = [];
  List<Map<String, dynamic>> _ca7Jours = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final db = await DbHelper.instance.db;
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day).toIso8601String();
    final debutMois = DateTime(now.year, now.month).toIso8601String();
    final debut7j = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6))
        .toIso8601String();

    final jour = await db.rawQuery(
        'SELECT COALESCE(SUM(montant),0) AS total, COUNT(*) AS n FROM ventes WHERE dateVente >= ?',
        [debutJour]);
    final mois = await db.rawQuery(
        'SELECT COALESCE(SUM(montant),0) AS total, COUNT(*) AS n FROM ventes WHERE dateVente >= ?',
        [debutMois]);
    final stock = await db.rawQuery(
        'SELECT COALESCE(SUM(quantite * prixAchat),0) AS achat, COALESCE(SUM(quantite * prixVente),0) AS vente FROM perruques');
    final marge = await db.rawQuery('''
      SELECT COALESCE(SUM(v.montant - p.prixAchat * v.quantite), 0) AS marge
      FROM ventes v JOIN perruques p ON p.id = v.perruqueId
      WHERE v.dateVente >= ?
    ''', [debutMois]);
    final best = await db.rawQuery('''
      SELECT p.nom, SUM(v.quantite) AS totalVendus, SUM(v.montant) AS ca
      FROM ventes v JOIN perruques p ON p.id = v.perruqueId
      GROUP BY v.perruqueId
      ORDER BY totalVendus DESC
      LIMIT 5
    ''');
    final perruques = await db.query('perruques', orderBy: 'nom');
    final ventesRes = await db.rawQuery('''
      SELECT v.*, p.nom AS nomPerruque
      FROM ventes v LEFT JOIN perruques p ON p.id = v.perruqueId
      ORDER BY v.dateVente DESC
    ''');
    final ca7 = await db.rawQuery('''
      SELECT date(dateVente) AS jour, COALESCE(SUM(montant),0) AS total
      FROM ventes
      WHERE dateVente >= ?
      GROUP BY date(dateVente)
      ORDER BY jour ASC
    ''', [debut7j]);

    if (!mounted) return;
    setState(() {
      _caJour = (jour.first['total'] as num).toDouble();
      _nbVentesJour = (jour.first['n'] as num).toInt();
      _caMois = (mois.first['total'] as num).toDouble();
      _nbVentesMois = (mois.first['n'] as num).toInt();
      _valeurStockAchat = (stock.first['achat'] as num).toDouble();
      _margeVendue = (marge.first['marge'] as num).toDouble();
      _bestSellers = best;
      _alertes =
          perruques.map(Perruque.fromMap).where((p) => p.stockBas).toList();
      _ventes = ventesRes;
      _ca7Jours = ca7;
      _chargement = false;
    });
  }

  Future<void> _exporterVentes() async {
    await exporterCsv(
      nomFichier: 'ventes',
      entetes: const [
        'Date', 'Perruque', 'Quantite', 'Montant', 'ModePaiement'
      ],
      lignes: _ventes
          .map((v) => [
                v['dateVente'],
                v['nomPerruque'] ?? '',
                v['quantite'] ?? 1,
                v['montant'],
                v['modePaiement'],
              ])
          .toList(),
    );
  }

  Future<void> _exporterVentesPdf() async {
    final lignes = _ventes
        .map((v) => [
              v['dateVente'].toString(),
              (v['nomPerruque'] ?? '').toString(),
              (v['quantite'] ?? 1).toString(),
              v['montant'].toString(),
              v['modePaiement'].toString(),
            ])
        .toList();
    await exporterRapportPdf(
      titre: 'Liste des ventes',
      sousTitre: 'CA jour: ${formatFcfa(_caJour)} | CA mois: ${formatFcfa(_caMois)}',
      entetes: const ['Date', 'Article', 'Qté', 'Montant (FCFA)', 'Paiement'],
      lignes: lignes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final estAdmin = context.watch<AuthProvider>().isAdmin;
    if (!estAdmin) {
      return const AccesRefuse(
        message:
            'Les statistiques financières sont réservées à l\'administrateur.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          IconButton(
            tooltip: 'Exporter les ventes (CSV)',
            icon: const Icon(Icons.table_view_outlined),
            onPressed: _exporterVentes,
          ),
          IconButton(
            tooltip: 'Exporter les ventes (PDF)',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporterVentesPdf,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              color: AppColors.rose,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _grilleIndicateurs(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'CA des 7 derniers jours'),
                  const SizedBox(height: 10),
                  _graphiqueCA(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Meilleures ventes'),
                  const SizedBox(height: 10),
                  if (_bestSellers.isEmpty)
                    _blocVide(
                      icon: Icons.emoji_events_outlined,
                      texte: 'Aucune vente enregistrée pour le moment.',
                    )
                  else
                    _carteBestSellers(),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Alertes stock bas (≤ 3)',
                    actionLabel: _alertes.isEmpty ? null : '${_alertes.length}',
                  ),
                  const SizedBox(height: 10),
                  if (_alertes.isEmpty)
                    _blocVide(
                      icon: Icons.check_circle_outline,
                      texte: 'Aucune alerte, le stock est suffisant.',
                      accent: AppColors.success,
                      fond: AppColors.successSoft,
                    )
                  else
                    _carteAlertes(),
                ],
              ),
            ),
    );
  }

  Widget _grilleIndicateurs() {
    return LayoutBuilder(
      builder: (ctx, contraintes) {
        final colonnes = contraintes.maxWidth >= 720 ? 4 : 2;
        final largeur =
            (contraintes.maxWidth - (colonnes - 1) * 12) / colonnes;

        Widget element(Widget enfant) => SizedBox(
              width: largeur,
              height: 138,
              child: enfant,
            );

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            element(StatCard(
              icon: Icons.payments_outlined,
              label: 'CA du jour • $_nbVentesJour vente(s)',
              value: formatFcfa(_caJour),
              accent: AppColors.success,
              background: AppColors.successSoft,
            )),
            element(StatCard(
              icon: Icons.calendar_month_outlined,
              label: 'CA du mois • $_nbVentesMois vente(s)',
              value: formatFcfa(_caMois),
              accent: AppColors.roseDeep,
              background: AppColors.roseSoft,
            )),
            element(StatCard(
              icon: Icons.inventory_2_outlined,
              label: 'Valeur du stock (achat)',
              value: formatFcfa(_valeurStockAchat),
              accent: const Color(0xFF5F7A9B),
              background: const Color(0xFFE7EEF6),
            )),
            element(StatCard(
              icon: Icons.trending_up_rounded,
              label: 'Marge vendue (mois)',
              value: formatFcfa(_margeVendue),
              accent: AppColors.gold,
              background: AppColors.goldSoft,
            )),
          ],
        );
      },
    );
  }

  Widget _carteBestSellers() {
    final maxVendus = _bestSellers.fold<int>(
      0,
      (max, b) => (b['totalVendus'] as num).toInt() > max
          ? (b['totalVendus'] as num).toInt()
          : max,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _bestSellers.length; i++) ...[
            if (i > 0) const Divider(),
            _ligneBestSeller(_bestSellers[i], i, maxVendus),
          ],
        ],
      ),
    );
  }

  Widget _ligneBestSeller(
      Map<String, dynamic> b, int index, int maxVendus) {
    final vendus = (b['totalVendus'] as num).toInt();
    final ca = (b['ca'] as num).toDouble();
    final ratio = maxVendus == 0 ? 0.0 : vendus / maxVendus;
    final couleur = switch (index) {
      0 => AppColors.gold,
      1 => const Color(0xFF9AA3AD),
      2 => const Color(0xFFB07B52),
      _ => AppColors.rose,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: couleur,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${b['nom']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.plum,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatFcfa(ca),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.roseDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 5,
                          backgroundColor: AppColors.cream,
                          color: couleur,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$vendus vendu(s)',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteAlertes() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _alertes.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _alertes[i].nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.plum,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_alertes[i].type} • ${_alertes[i].couleur} • '
                          '${formatFcfa(_alertes[i].prixVente)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_alertes[i].quantite} restant(s)',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _graphiqueCA() {
    if (_ca7Jours.isEmpty) {
      return _blocVide(
        icon: Icons.show_chart_rounded,
        texte: 'Aucune donnée sur les 7 derniers jours.',
      );
    }
    final maxY = _ca7Jours.fold<double>(
      0,
      (m, e) => ((e['total'] as num).toDouble()) > m
          ? ((e['total'] as num).toDouble())
          : m,
    );
    final spots = <FlSpot>[];
    for (var i = 0; i < _ca7Jours.length; i++) {
      spots.add(FlSpot(i.toDouble(), (_ca7Jours[i]['total'] as num).toDouble()));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 18, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 1000 : maxY * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= _ca7Jours.length) return const SizedBox.shrink();
                  final jour = _ca7Jours[i]['jour'].toString();
                  final parts = jour.split('-');
                  final label = parts.length == 3 ? '${parts[2]}/${parts[1]}' : jour;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.rose,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.rose.withValues(alpha: 0.18),
                    AppColors.rose.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blocVide({
    required IconData icon,
    required String texte,
    Color accent = AppColors.muted,
    Color fond = AppColors.surface,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

