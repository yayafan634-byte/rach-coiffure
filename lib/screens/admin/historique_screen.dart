import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../navigation/app_section.dart';
import '../../services/activite_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/journal.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/initials_avatar.dart';

class _Activite {
  final int? id;
  final String? utilisateur;
  final String action;
  final String? details;
  final DateTime date;

  const _Activite({
    this.id,
    this.utilisateur,
    required this.action,
    this.details,
    required this.date,
  });

  factory _Activite.fromMap(Map<String, dynamic> m) => _Activite(
        id: m['id'] as int?,
        utilisateur: m['utilisateur'] as String?,
        action: (m['action'] as String?) ?? 'Action',
        details: m['details'] as String?,
        date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
      );
}

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  List<_Activite> _activites = [];
  bool _chargement = true;
  int _periode = 0; // 0 = tout, 1 = aujourd'hui, 7 = 7 jours
  String? _utilisateur;
  String _recherche = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final db = await DbHelper.instance.db;
      final res = await db.query(
        'activites',
        orderBy: 'date DESC, id DESC',
        limit: 2000,
      );
      if (!mounted) return;
      setState(() {
        _activites = res.map(_Activite.fromMap).toList();
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargement = false);
      showAppSnack(
        context,
        'Impossible de charger l\'historique.',
        type: AppSnackType.error,
      );
    }
  }

  List<String> get _utilisateurs {
    final noms = <String>{};
    for (final a in _activites) {
      final nom = a.utilisateur?.trim();
      if (nom != null && nom.isNotEmpty) noms.add(nom);
    }
    final liste = noms.toList()..sort();
    return liste;
  }

  List<_Activite> get _filtres {
    final q = _recherche.toLowerCase();
    final maintenant = DateTime.now();
    final debutJour =
        DateTime(maintenant.year, maintenant.month, maintenant.day);
    final debut7j = debutJour.subtract(const Duration(days: 6));

    return _activites.where((a) {
      if (_periode == 1 && a.date.isBefore(debutJour)) return false;
      if (_periode == 7 && a.date.isBefore(debut7j)) return false;
      if (_utilisateur != null && a.utilisateur != _utilisateur) return false;
      if (q.isEmpty) return true;
      final texte =
          '${a.action} ${a.details ?? ''} ${a.utilisateur ?? ''}'.toLowerCase();
      return texte.contains(q);
    }).toList();
  }

  Future<void> _vider() async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider l\'historique ?'),
        content: const Text(
          'Toutes les actions enregistrées seront définitivement supprimées. '
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
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (confirmer != true) return;

    final nombre = _activites.length;
    await ActiviteService.instance.vider();
    if (!mounted) return;
    await journaliser(
      context,
      'Historique vidé',
      details: '$nombre action(s) supprimée(s)',
    );
    await _charger();
    if (!mounted) return;
    showAppSnack(
      context,
      'Historique vidé.',
      type: AppSnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return const AccesRefuse(
        message: 'L\'historique complet est réservé à l\'administrateur.',
      );
    }

    final filtres = _filtres;
    final utilisateurs = _utilisateurs;

    return AppShell(
      section: AppSection.historique,
      title: 'Historique',
      actions: [
        IconButton(
          tooltip: 'Rafraîchir',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _charger,
        ),
        IconButton(
          tooltip: 'Vider l\'historique',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: _activites.isEmpty ? null : _vider,
        ),
        const SizedBox(width: 4),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher une action, un détail, un utilisateur',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _recherche.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _recherche = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _recherche = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Tout'),
                          selected: _periode == 0,
                          onSelected: (_) => setState(() => _periode = 0),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Aujourd\'hui'),
                          selected: _periode == 1,
                          onSelected: (_) => setState(() => _periode = 1),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('7 jours'),
                          selected: _periode == 7,
                          onSelected: (_) => setState(() => _periode = 7),
                        ),
                      ],
                    ),
                  ),
                ),
                if (utilisateurs.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  DropdownButton<String?>(
                    value: _utilisateur,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Utilisateur'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tous'),
                      ),
                      ...utilisateurs.map(
                        (u) => DropdownMenuItem<String?>(
                          value: u,
                          child: Text(u),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _utilisateur = v),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtres.length} action(s)',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : filtres.isEmpty
                    ? EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Aucune action',
                        message: _activites.isEmpty
                            ? 'Les connexions, ventes, modifications de stock et changements de comptes apparaîtront ici.'
                            : 'Aucune action ne correspond à vos filtres.',
                        actionLabel:
                            _activites.isEmpty ? null : 'Réinitialiser',
                        onAction: _activites.isEmpty
                            ? null
                            : () {
                                _searchCtrl.clear();
                                setState(() {
                                  _recherche = '';
                                  _periode = 0;
                                  _utilisateur = null;
                                });
                              },
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        color: AppColors.rose,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtres.length,
                          itemBuilder: (ctx, i) => _entree(filtres, i),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _entree(List<_Activite> liste, int index) {
    final a = liste[index];
    final precedent = index == 0 ? null : liste[index - 1];
    final nouveauJour = precedent == null ||
        precedent.date.year != a.date.year ||
        precedent.date.month != a.date.month ||
        precedent.date.day != a.date.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nouveauJour) _enteteJour(a.date),
        _carte(a),
      ],
    );
  }

  Widget _enteteJour(DateTime date) {
    final maintenant = DateTime.now();
    final jour = DateTime(date.year, date.month, date.day);
    final aujourdhui =
        DateTime(maintenant.year, maintenant.month, maintenant.day);
    final hier = aujourdhui.subtract(const Duration(days: 1));
    final libelle = jour == aujourdhui
        ? 'Aujourd\'hui'
        : jour == hier
            ? 'Hier'
            : dateLongueFrCapitalisee(date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(
        libelle,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: AppColors.slate500,
        ),
      ),
    );
  }

  Widget _carte(_Activite a) {
    final (icone, accent, fond) = _style(a.action);
    final utilisateur = (a.utilisateur?.trim().isNotEmpty ?? false)
        ? a.utilisateur!.trim()
        : 'Système';

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: fond,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icone, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.action,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.plum,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatHeure(a.date),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (a.details != null && a.details!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      a.details!.trim(),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      InitialsAvatar(name: utilisateur, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          utilisateur,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _style(String action) {
    final a = action.toLowerCase();
    if (a.contains('vente') || a.contains('encaiss')) {
      return (
        Icons.point_of_sale_rounded,
        AppColors.roseDeep,
        AppColors.roseSoft
      );
    }
    if (a.contains('connexion')) {
      return (Icons.login_rounded, AppColors.blue, const Color(0xFFE4EFF7));
    }
    if (a.contains('déconnexion')) {
      return (Icons.logout_rounded, AppColors.slate500, AppColors.surfaceAlt);
    }
    if (a.contains('article') || a.contains('stock')) {
      return (Icons.inventory_2_outlined, AppColors.gold, AppColors.goldSoft);
    }
    if (a.contains('client')) {
      return (
        Icons.people_alt_outlined,
        AppColors.success,
        AppColors.successSoft
      );
    }
    if (a.contains('rendez')) {
      return (
        Icons.event_available_rounded,
        AppColors.violet,
        const Color(0xFFEFE8F7)
      );
    }
    if (a.contains('compte') ||
        a.contains('utilisateur') ||
        a.contains('autorisation')) {
      return (
        Icons.manage_accounts_outlined,
        AppColors.amber,
        const Color(0xFFFFF4E5)
      );
    }
    if (a.contains('export')) {
      return (Icons.ios_share_rounded, AppColors.cyan, const Color(0xFFE0F7FA));
    }
    if (a.contains('sauvegarde')) {
      return (Icons.backup_outlined, AppColors.blue, const Color(0xFFE4EFF7));
    }
    return (Icons.history_rounded, AppColors.slate500, AppColors.surfaceAlt);
  }
}
