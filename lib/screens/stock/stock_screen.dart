import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/perruque.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/export_csv.dart';
import '../../utils/format.dart';
import '../../utils/photo_image.dart';
import '../../widgets/empty_state.dart';
import 'mouvements_screen.dart';
import 'stock_form_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Perruque> _tous = [];
  String _recherche = '';
  bool _filtreStockBas = false;
  bool _chargement = true;
  final _searchCtrl = TextEditingController();

  List<Perruque> get _perruques => _tous.where((p) {
        final q = _recherche.toLowerCase();
        final correspond = q.isEmpty ||
            p.nom.toLowerCase().contains(q) ||
            p.type.toLowerCase().contains(q) ||
            p.couleur.toLowerCase().contains(q) ||
            p.texture.toLowerCase().contains(q);
        return correspond && (!_filtreStockBas || p.stockBas);
      }).toList();

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
    final res = await db.query('perruques', orderBy: 'nom');
    if (!mounted) return;
    setState(() {
      _tous = res.map(Perruque.fromMap).toList();
      _chargement = false;
    });
  }

  Future<void> _supprimer(Perruque p) async {
    if (!context.read<AuthProvider>().isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Suppression réservée à l\'administrateur.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    final nbVentes = await StockService.instance.ventesLiees(p.id!);
    if (!mounted) return;
    if (nbVentes > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Impossible de supprimer "${p.nom}" : $nbVentes vente(s) liée(s)'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    final db = await DbHelper.instance.db;
    await db.delete('perruques', where: 'id = ?', whereArgs: [p.id]);
    _charger();
  }

  Future<void> _exporter() async {
    if (!context.read<AuthProvider>().isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Export réservé à l\'administrateur.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    await exporterCsv(
      nomFichier: 'stock_perruques',
      entetes: const [
        'Nom', 'Type', 'Longueur', 'Couleur', 'Texture',
        'Quantite', 'PrixAchat', 'PrixVente', 'ValeurAchat'
      ],
      lignes: _perruques
          .map((p) => [
                p.nom, p.type, p.longueur, p.couleur, p.texture,
                p.quantite, p.prixAchat, p.prixVente,
                (p.quantite * p.prixAchat).toStringAsFixed(0),
              ])
          .toList(),
    );
  }

  Future<void> _ouvrirFormulaire({Perruque? perruque}) async {
    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StockFormScreen(perruque: perruque),
      ),
    );
    if (enregistre == true) _charger();
  }

  void _reinitialiser() {
    _searchCtrl.clear();
    setState(() {
      _recherche = '';
      _filtreStockBas = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estAdmin = context.watch<AuthProvider>().isAdmin;
    final nbStockBas = _tous.where((p) => p.stockBas).length;
    final valeur =
        _tous.fold<double>(0, (s, p) => s + p.quantite * p.prixAchat);
    final filtrees = _perruques;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock perruques'),
        actions: [
          IconButton(
            tooltip: 'Historique du stock',
            icon: const Icon(Icons.history_rounded),
            onPressed: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MouvementsScreen()));
              _charger();
            },
          ),
          if (estAdmin)
            IconButton(
              tooltip: 'Exporter en CSV',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _exporter,
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Article'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, type, couleur...)',
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: !_filtreStockBas,
                  onSelected: (_) =>
                      setState(() => _filtreStockBas = false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Stock bas ($nbStockBas)'),
                  selected: _filtreStockBas,
                  selectedColor: AppColors.dangerSoft,
                  onSelected: (_) =>
                      setState(() => _filtreStockBas = true),
                ),
                const Spacer(),
                Text(
                  '${filtrees.length} article(s)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (estAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 18, color: AppColors.gold),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Valeur du stock (achat)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Text(
                      formatFcfa(valeur),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.plum,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _tous.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Aucun article',
                        message:
                            'Ajoutez votre première perruque pour démarrer le stock du salon.',
                        actionLabel: 'Ajouter un article',
                        onAction: () => _ouvrirFormulaire(),
                      )
                    : filtrees.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Aucun résultat',
                            message:
                                'Aucun article ne correspond à votre recherche.',
                            actionLabel: 'Réinitialiser',
                            onAction: _reinitialiser,
                          )
                        : RefreshIndicator(
                            onRefresh: _charger,
                            color: AppColors.rose,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filtrees.length,
                              itemBuilder: (ctx, i) =>
                                  _carteArticle(filtrees[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _carteArticle(Perruque p) {
    final estAdmin = context.watch<AuthProvider>().isAdmin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          onTap: () => _ouvrirFormulaire(perruque: p),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _vignette(p),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${p.type} • ${p.longueur} • ${p.couleur}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _badgeStock(p),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formatFcfa(p.prixVente),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.roseDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.muted),
                  onSelected: (valeur) {
                    if (valeur == 'modifier') {
                      _ouvrirFormulaire(perruque: p);
                    } else {
                      _supprimerDialog(p);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'modifier',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    if (estAdmin)
                      const PopupMenuItem(
                        value: 'supprimer',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: AppColors.danger),
                            SizedBox(width: 10),
                            Text(
                              'Supprimer',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vignette(Perruque p) {
    final provider = photoImageProvider(p.photoPath);

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.roseSoft,
        borderRadius: BorderRadius.circular(14),
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : null,
      ),
      child: provider != null
          ? null
          : const Icon(Icons.content_cut, size: 24, color: AppColors.rose),
    );
  }

  Widget _badgeStock(Perruque p) {
    final bas = p.stockBas;
    final rupture = p.quantite <= 0;
    final accent = rupture
        ? AppColors.danger
        : bas
            ? AppColors.warning
            : AppColors.success;
    final fond = rupture
        ? AppColors.dangerSoft
        : bas
            ? AppColors.warningSoft
            : AppColors.successSoft;
    final texte = rupture
        ? 'Rupture'
        : bas
            ? 'Stock bas : ${p.quantite}'
            : '${p.quantite} en stock';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }

  void _supprimerDialog(Perruque p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer "${p.nom}" ?'),
        content: const Text(
            'Cette action est irréversible. Les articles déjà vendus restent dans l\'historique des ventes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              _supprimer(p);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
