import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../navigation/app_section.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/initials_avatar.dart';
import 'client_detail_screen.dart';
import 'client_form_sheet.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> _clients = [];
  String _recherche = '';
  bool _chargement = true;
  final _searchCtrl = TextEditingController();

  List<Client> get _filtres {
    final q = _recherche.toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients
        .where((c) =>
            c.nom.toLowerCase().contains(q) ||
            c.telephone.toLowerCase().contains(q))
        .toList();
  }

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
      final res = await db.query('clients', orderBy: 'nom');
      if (!mounted) return;
      setState(() {
        _clients = res.map(Client.fromMap).toList();
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargement = false);
      showAppSnack(
        context,
        'Impossible de charger les clients.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _ajouter() async {
    final ajoute = await showClientFormSheet(context);
    if (ajoute) _charger();
  }

  void _details(Client c) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c)),
        )
        .then((_) => _charger());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.peut('clients')) {
      return const AccesRefuse(
        message: 'La gestion des clients n\'est pas autorisée pour ce compte.',
      );
    }

    final filtres = _filtres;
    final totalPoints = _clients.fold<int>(0, (s, c) => s + c.pointsFidelite);

    return AppShell(
      section: AppSection.clients,
      title: 'Clients',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Client'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher un nom ou un téléphone',
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
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(
                  '${_clients.length} client(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.stars_rounded,
                    size: 16, color: AppColors.gold),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$totalPoints pts cumulés',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _clients.isEmpty
                    ? EmptyState(
                        icon: Icons.people_alt_outlined,
                        title: 'Aucun client',
                        message:
                            'Ajoutez votre premier client pour suivre ses visites et sa fidélité.',
                        actionLabel: 'Ajouter un client',
                        onAction: _ajouter,
                      )
                    : filtres.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Aucun résultat',
                            message:
                                'Aucun client ne correspond à votre recherche.',
                            actionLabel: 'Réinitialiser',
                            onAction: () {
                              _searchCtrl.clear();
                              setState(() => _recherche = '');
                            },
                          )
                        : RefreshIndicator(
                            onRefresh: _charger,
                            color: AppColors.rose,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filtres.length,
                              itemBuilder: (ctx, i) => _carteClient(filtres[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _carteClient(Client c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          onTap: () => _details(c),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InitialsAvatar(name: c.nom, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.telephone,
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: AppColors.gold),
                      const SizedBox(width: 3),
                      Text(
                        '${c.pointsFidelite}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
