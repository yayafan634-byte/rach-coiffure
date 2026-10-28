import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../auth/login_screen.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../caisse/caisse_screen.dart';
import '../clients/clients_screen.dart';
import '../rdv/rdv_screen.dart';
import '../stats/stats_screen.dart';
import '../stock/stock_screen.dart';
import '../admin/gestion_users.dart';

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

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final db = await DbHelper.instance.db;
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day);
    final debutDemain = debutJour.add(const Duration(days: 1));

    final ca = await db.rawQuery(
      'SELECT COALESCE(SUM(montant),0) AS total, COUNT(*) AS n FROM ventes WHERE dateVente >= ?',
      [debutJour.toIso8601String()],
    );
    final stock = await db.rawQuery('SELECT COUNT(*) AS n FROM perruques WHERE quantite <= 3');
    final rdv = await db.rawQuery('SELECT COUNT(*) AS n FROM rendezVous WHERE dateHeure >= ? AND dateHeure < ?', [debutJour.toIso8601String(), debutDemain.toIso8601String()]);

    if (!mounted) return;
    setState(() {
      _caJour = (ca.first['total'] as num).toDouble();
      _nbVentesJour = (ca.first['n'] as num).toInt();
      _stockBas = (stock.first['n'] as num).toInt();
      _rdvJour = (rdv.first['n'] as num).toInt();
      _loading = false;
    });
  }

  Future<void> _deconnexion() async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Confirmer la déconnexion.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Déconnexion')),
        ],
      ),
    );
    if (confirmer != true || !mounted) return;
    context.read<AuthProvider>().logout();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _ouvrir(Widget ecran) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran));

  String _initiales(String nom) {
    final parts = nom.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'SP';
    if (parts.length == 1) {
      final s = parts.first;
      return s.isEmpty ? 'SP' : s.substring(0, math.min(2, s.length)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _jour(int d) {
    const j = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return j[(d - 1) % 7];
  }

  String _mois(int m) {
    const mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return mois[(m - 1) % 12];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final nom = user?.nom ?? 'Utilisateur';
    final estAdmin = auth.isAdmin;
    final role = estAdmin ? 'Administrateur' : 'Gestionnaire';
    final now = DateTime.now();
    final dateStr = '${_jour(now.weekday)} ${now.day.toString().padLeft(2, '0')} ${_mois(now.month)} ${now.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _charger,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.rose.withValues(alpha: 0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bonjour, $nom', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate900, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                                const SizedBox(height: 2),
                                Text('$role • $dateStr', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Se déconnecter',
                            onPressed: _deconnexion,
                            style: IconButton.styleFrom(backgroundColor: AppColors.surface, side: const BorderSide(color: AppColors.line), shape: const CircleBorder()),
                            icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.slate700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
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
                          const Text('Aperçu du jour', style: TextStyle(color: AppColors.slate900, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        int cols = width >= 920 ? 4 : width >= 680 ? 3 : width >= 420 ? 2 : 1;
                        return GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: cols == 1 ? 3.6 : cols == 2 ? 1.9 : 1.6,
                          children: [
                            _ApercuCard(icon: Icons.payments_rounded, label: estAdmin ? 'Chiffre du jour' : 'Ventes du jour', value: _loading ? '...' : (estAdmin ? formatFcfa(_caJour) : '$_nbVentesJour'), color: AppColors.emerald, delay: 0),
                            _ApercuCard(icon: Icons.inventory_2_rounded, label: 'Stock bas', value: _loading ? '...' : '$_stockBas', color: _stockBas > 0 ? AppColors.primary : AppColors.emerald, delay: 60, onTap: () => _ouvrir(const StockScreen())),
                            _ApercuCard(icon: Icons.event_available_rounded, label: 'RDV du jour', value: _loading ? '...' : '$_rdvJour', color: AppColors.blue, delay: 120, onTap: () => _ouvrir(const RdvScreen())),
                            _ApercuCard(icon: Icons.point_of_sale_rounded, label: 'Caisse', value: _loading ? '...' : 'Ouvrir', color: AppColors.violet, delay: 180, onTap: () => _ouvrir(const CaisseScreen())),
                          ],
                        );
                      }),
                      const SizedBox(height: 28),
                      Row(
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
                          const Text('Menu principal', style: TextStyle(color: AppColors.slate900, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        int cols = width >= 1100 ? 3 : width >= 720 ? 2 : 1;
                        final items = <_MenuItem>[
                          _MenuItem(icon: Icons.inventory_2_rounded, label: 'Stock', subtitle: 'Perruques & quantités', color: AppColors.primary, onTap: () => _ouvrir(const StockScreen())),
                          _MenuItem(icon: Icons.people_alt_rounded, label: 'Clients', subtitle: 'Répertoire & fidélité', color: AppColors.blue, onTap: () => _ouvrir(const ClientsScreen())),
                          _MenuItem(icon: Icons.point_of_sale_rounded, label: 'Caisse', subtitle: 'Encaisser une vente', color: AppColors.emerald, onTap: () => _ouvrir(const CaisseScreen())),
                          _MenuItem(icon: Icons.calendar_month_rounded, label: 'Rendez-vous', subtitle: 'Agenda du salon', color: AppColors.violet, onTap: () => _ouvrir(const RdvScreen())),
                          if (estAdmin) _MenuItem(icon: Icons.bar_chart_rounded, label: 'Statistiques', subtitle: 'Ventes, marges & top', color: AppColors.cyan, onTap: () => _ouvrir(const StatsScreen())),
                          if (estAdmin) _MenuItem(icon: Icons.manage_accounts_rounded, label: 'Utilisateurs', subtitle: 'Comptes du personnel', color: AppColors.amber, onTap: () => _ouvrir(const GestionUsersScreen())),
                        ];
                        return GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: cols == 1 ? 3.6 : cols == 2 ? 2.0 : 1.9,
                          children: [for (int i = 0; i < items.length; i++) _MenuTile(item: items[i], delay: i * 40)],
                        );
                      }),
                      const SizedBox(height: 26),
                      if (estAdmin)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.amber.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.amber),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Accès Administrateur', style: TextStyle(color: AppColors.slate900, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                                SizedBox(height: 2),
                                Text('Statistiques & gestion des utilisateurs disponibles', style: TextStyle(color: AppColors.slate500, fontSize: 13)),
                              ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF0F9FF), Color(0xFFF8FAFC)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.badge_rounded, color: AppColors.blue),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Accès Gestionnaire', style: TextStyle(color: AppColors.slate900, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                                SizedBox(height: 2),
                                Text('Stock, Clients, Caisse & Rendez-vous', style: TextStyle(color: AppColors.slate500, fontSize: 13)),
                              ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      _AlerteStock(actif: _stockBas > 0, count: _stockBas),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApercuCard extends StatefulWidget {
  final IconData icon; final String label; final String value; final Color color; final int delay; final VoidCallback? onTap;
  const _ApercuCard({required this.icon, required this.label, required this.value, required this.color, required this.delay, this.onTap});
  @override
  State<_ApercuCard> createState() => _ApercuCardState();
}

class _ApercuCardState extends State<_ApercuCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  @override
  void initState() { super.initState(); Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.forward(); }); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Icon(widget.icon, color: widget.color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(widget.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate900, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)), const SizedBox(height: 2), Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate500, fontSize: 13))])),
        ],
      ),
    );
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.onTap == null ? card : Material(color: Colors.transparent, child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(16), child: card))));
  }
}

class _MenuItem { final IconData icon; final String label; final String subtitle; final Color color; final VoidCallback onTap; _MenuItem({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap}); }

class _MenuTile extends StatefulWidget {
  final _MenuItem item; final int delay;
  const _MenuTile({required this.item, required this.delay});
  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  @override
  void initState() { super.initState(); Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.forward(); }); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.line)),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: item.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Icon(item.icon, color: item.color, size: 24)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(item.label, style: const TextStyle(color: AppColors.slate900, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)), const SizedBox(height: 4), Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate500, fontSize: 13))])),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.slate400),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlerteStock extends StatelessWidget {
  final bool actif; final int count;
  const _AlerteStock({required this.actif, required this.count});
  @override
  Widget build(BuildContext context) {
    if (!actif) {
      return Container(decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4))), padding: const EdgeInsets.all(16), child: const Row(children: [Icon(Icons.check_circle_rounded, color: AppColors.emerald), SizedBox(width: 12), Expanded(child: Text('Tout est en ordre. Aucun produit en stock bas.', style: TextStyle(color: AppColors.slate900, fontSize: 14)))]));
    }
    return Container(decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.4))), padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: AppColors.primary), const SizedBox(width: 12), Expanded(child: Text('$count article(s) en stock bas. À réapprovisionner rapidement.', style: const TextStyle(color: AppColors.slate900, fontSize: 14)))]));
  }
}
