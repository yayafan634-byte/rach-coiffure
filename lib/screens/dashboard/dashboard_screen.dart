import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/permission.dart';
import '../../navigation/app_section.dart';
import '../../services/cloud_sync.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_snack.dart';
import '../admin/gestion_users.dart';
import '../admin/historique_screen.dart';
import '../caisse/caisse_screen.dart';
import '../clients/clients_screen.dart';
import '../rdv/rdv_screen.dart';
import '../stats/stats_screen.dart';
import '../stock/stock_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _caJour = 0;
  int _nbVentesJour = 0;
  int _stockBas = 0;
  int _rdvJour = 0;
  bool _loading = true;
  bool _syncEnCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final db = await DbHelper.instance.db;
      final now = DateTime.now();
      final debutJour = DateTime(now.year, now.month, now.day);
      final debutDemain = debutJour.add(const Duration(days: 1));

      final ca = await db.rawQuery(
        'SELECT COALESCE(SUM(montant),0) AS total, COUNT(*) AS n '
        'FROM ventes WHERE dateVente >= ? AND dateVente < ?',
        [debutJour.toIso8601String(), debutDemain.toIso8601String()],
      );
      final stock = await db
          .rawQuery('SELECT COUNT(*) AS n FROM perruques WHERE quantite <= 3');
      final rdv = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM rendezVous '
        'WHERE dateHeure >= ? AND dateHeure < ?',
        [debutJour.toIso8601String(), debutDemain.toIso8601String()],
      );

      if (!mounted) return;
      setState(() {
        _caJour = (ca.first['total'] as num).toDouble();
        _nbVentesJour = (ca.first['n'] as num).toInt();
        _stockBas = (stock.first['n'] as num).toInt();
        _rdvJour = (rdv.first['n'] as num).toInt();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnack(
        context,
        'Impossible de charger les données du jour.',
        type: AppSnackType.error,
      );
    }
  }

  void _ouvrir(Widget ecran) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ecran),
      );

  Future<void> _synchroniser() async {
    if (_syncEnCours) return;
    setState(() => _syncEnCours = true);
    final res = await CloudSync.instance.synchroniser(force: true);
    if (!mounted) return;
    setState(() => _syncEnCours = false);
    showAppSnack(
      context,
      res.message,
      type: res.ok ? AppSnackType.success : AppSnackType.error,
    );
    if (res.donneesRecues) await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final nom = (user?.nom.trim().isNotEmpty ?? false)
        ? user!.nom.trim()
        : 'Utilisateur';
    final estAdmin = auth.isAdmin;
    final role = estAdmin ? 'Administrateur' : 'Gestionnaire';
    final dateStr = dateLongueFrCapitalisee(DateTime.now());

    return AppShell(
      section: AppSection.dashboard,
      title: 'Tableau de bord',
      actions: [
        IconButton(
          tooltip: 'Synchroniser avec le cloud',
          icon: _syncEnCours
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync_outlined),
          onPressed: _synchroniser,
        ),
        if (_stockBas > 0)
          IconButton(
            tooltip: 'Alerte stock bas ($_stockBas)',
            icon: Badge.count(
              count: _stockBas,
              child: const Icon(Icons.warning_amber_rounded),
            ),
            onPressed: () => _ouvrir(
              const StockScreen(filtreStockBasInitial: true),
            ),
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _charger,
        color: AppColors.rose,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _salutation(nom, role, dateStr),
            const SizedBox(height: 26),
            const _SectionTitle('Aperçu du jour'),
            const SizedBox(height: 14),
            _apercu(auth),
            const SizedBox(height: 26),
            const _SectionTitle('Accès rapides'),
            const SizedBox(height: 12),
            _accesRapides(auth),
            const SizedBox(height: 26),
            _bandeauRole(auth: auth, nom: nom),
            const SizedBox(height: 16),
            _AlerteStock(
              actif: _stockBas > 0,
              count: _stockBas,
              onTap: () => _ouvrir(
                const StockScreen(filtreStockBasInitial: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _salutation(String nom, String role, String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour, $nom',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.slate900,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$role • $dateStr',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.slate500,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }

  Widget _accesRapides(AuthProvider auth) {
    final items = _menuItems(auth);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 940
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 82,
          ),
          itemBuilder: (context, index) => _carteAcces(items[index]),
        );
      },
    );
  }

  Widget _carteAcces(_MenuItem item) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        splashColor: item.color.withValues(alpha: 0.08),
        highlightColor: item.color.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.plum,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _apercu(AuthProvider auth) {
    final estAdmin = auth.isAdmin;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 920
            ? 4
            : width >= 680
                ? 3
                : width >= 320
                    ? 2
                    : 1;

        final cartes = <Widget>[
          _ApercuCard(
            icon: Icons.payments_rounded,
            label: estAdmin ? 'Chiffre du jour' : 'Ventes du jour',
            value: _loading
                ? '...'
                : (estAdmin ? formatFcfa(_caJour) : '$_nbVentesJour'),
            color: AppColors.emerald,
            delay: 0,
          ),
          if (auth.peut('stock'))
            _ApercuCard(
              icon: Icons.inventory_2_rounded,
              label: 'Stock bas',
              value: _loading ? '...' : '$_stockBas',
              color: _stockBas > 0 ? AppColors.danger : AppColors.emerald,
              delay: 60,
              onTap: () => _ouvrir(const StockScreen()),
            ),
          if (auth.peut('caisse'))
            _ApercuCard(
              icon: Icons.point_of_sale_rounded,
              label: 'Caisse',
              value: _loading ? '...' : 'Ouvrir',
              color: AppColors.violet,
              delay: 120,
              onTap: () => _ouvrir(const CaisseScreen()),
            ),
          if (auth.peut('stats'))
            _ApercuCard(
              icon: Icons.bar_chart_rounded,
              label: 'Statistiques',
              value: _loading ? '...' : 'Analyser',
              color: AppColors.cyan,
              delay: 180,
              onTap: () => _ouvrir(const StatsScreen()),
            )
          else if (auth.peut('rdv'))
            _ApercuCard(
              icon: Icons.event_available_rounded,
              label: 'RDV du jour',
              value: _loading ? '...' : '$_rdvJour',
              color: AppColors.blue,
              delay: 180,
              onTap: () => _ouvrir(const RdvScreen()),
            ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cartes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 98,
          ),
          itemBuilder: (context, index) => cartes[index],
        );
      },
    );
  }

  List<_MenuItem> _menuItems(AuthProvider auth) {
    return [
      if (auth.peut('stock'))
        _MenuItem(
          icon: Icons.inventory_2_rounded,
          label: 'Stock',
          subtitle: 'Perruques & quantités',
          color: AppColors.rose,
          onTap: () => _ouvrir(const StockScreen()),
        ),
      if (auth.peut('clients'))
        _MenuItem(
          icon: Icons.people_alt_rounded,
          label: 'Clients',
          subtitle: 'Répertoire & fidélité',
          color: AppColors.blue,
          onTap: () => _ouvrir(const ClientsScreen()),
        ),
      if (auth.peut('caisse'))
        _MenuItem(
          icon: Icons.point_of_sale_rounded,
          label: 'Caisse',
          subtitle: 'Encaisser une vente',
          color: AppColors.emerald,
          onTap: () => _ouvrir(const CaisseScreen()),
        ),
      if (auth.peut('rdv'))
        _MenuItem(
          icon: Icons.calendar_month_rounded,
          label: 'Rendez-vous',
          subtitle: 'Agenda du salon',
          color: AppColors.violet,
          onTap: () => _ouvrir(const RdvScreen()),
        ),
      if (auth.peut('stats'))
        _MenuItem(
          icon: Icons.bar_chart_rounded,
          label: 'Statistiques',
          subtitle: 'Ventes, marges & top',
          color: AppColors.cyan,
          onTap: () => _ouvrir(const StatsScreen()),
        ),
      if (auth.isAdmin)
        _MenuItem(
          icon: Icons.manage_accounts_rounded,
          label: 'Utilisateurs',
          subtitle: 'Comptes & permissions',
          color: AppColors.amber,
          onTap: () => _ouvrir(const GestionUsersScreen()),
        ),
      if (auth.isAdmin)
        _MenuItem(
          icon: Icons.history_rounded,
          label: 'Historique',
          subtitle: 'Journal des actions',
          color: AppColors.slate500,
          onTap: () => _ouvrir(const HistoriqueScreen()),
        ),
    ];
  }

  Widget _bandeauRole({required AuthProvider auth, required String nom}) {
    final estAdmin = auth.isAdmin;
    final accent = estAdmin ? AppColors.amber : AppColors.blue;
    final fond = estAdmin
        ? const [Color(0xFFFFF7ED), Color(0xFFFFFBEB)]
        : const [Color(0xFFF0F9FF), Color(0xFFF8FAFC)];
    final titre = estAdmin ? 'Accès administrateur' : 'Accès gestionnaire';
    final libelles = kPermissions
        .where((p) => auth.peut(p.cle))
        .map((p) => p.label.toLowerCase())
        .toList();
    final texte = estAdmin
        ? '$nom • toutes les autorisations'
        : '$nom • ${libelles.isEmpty ? 'aucune autorisation accordée' : libelles.join(', ')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fond,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              estAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.badge_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    color: AppColors.slate900,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texte,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.rose,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.slate900,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _ApercuCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int delay;
  final VoidCallback? onTap;

  const _ApercuCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.delay,
    this.onTap,
  });

  @override
  State<_ApercuCard> createState() => _ApercuCardState();
}

class _ApercuCardState extends State<_ApercuCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = Ink(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, color: widget.color, size: 19),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate500,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.value,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.slate900,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Semantics(
          button: widget.onTap != null,
          label: '${widget.label} : ${widget.value}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _AlerteStock extends StatelessWidget {
  final bool actif;
  final int count;
  final VoidCallback? onTap;

  const _AlerteStock({
    required this.actif,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = actif ? AppColors.danger : AppColors.emerald;
    final fond = actif ? AppColors.dangerSoft : AppColors.successSoft;
    final icone =
        actif ? Icons.warning_amber_rounded : Icons.check_circle_rounded;
    final texte = actif
        ? '$count article(s) en stock bas. À réapprovisionner rapidement.'
        : 'Tout est en ordre. Aucun produit en stock bas.';

    return Material(
      color: fond,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: actif ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icone, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texte,
                  style: const TextStyle(
                    color: AppColors.slate900,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
              if (actif) ...[
                const SizedBox(width: 8),
                Text(
                  'Voir',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
