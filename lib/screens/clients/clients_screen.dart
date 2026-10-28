import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/empty_state.dart';
import 'client_detail_screen.dart';

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
    final db = await DbHelper.instance.db;
    final res = await db.query('clients', orderBy: 'nom');
    if (!mounted) return;
    setState(() {
      _clients = res.map(Client.fromMap).toList();
      _chargement = false;
    });
  }

  Future<void> _ajouter(Client c) async {
    final db = await DbHelper.instance.db;
    await db.insert('clients', c.toMap());
    await _charger();
  }

  void _ajouterDialog() {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final adresseCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nouveau client',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Text(
                  'Ajoutez un client au répertoire du salon.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nomCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nom requis'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Téléphone requis'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: adresseCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Adresse (optionnel)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      _ajouter(Client(
                        nom: nomCtrl.text.trim(),
                        telephone: telCtrl.text.trim(),
                        adresse: adresseCtrl.text.trim().isEmpty
                            ? null
                            : adresseCtrl.text.trim(),
                      ));
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text('Ajouter le client'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _details(Client c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c)),
    ).then((_) => _charger());
  }

  @override
  Widget build(BuildContext context) {
    final filtres = _filtres;
    final totalPoints =
        _clients.fold<int>(0, (s, c) => s + c.pointsFidelite);

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterDialog,
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
                const Spacer(),
                const Icon(Icons.stars_rounded,
                    size: 16, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  '$totalPoints pts cumulés',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
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
                        onAction: _ajouterDialog,
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              itemCount: filtres.length,
                              itemBuilder: (ctx, i) =>
                                  _carteClient(filtres[i]),
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
                _avatar(c, 42),
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
