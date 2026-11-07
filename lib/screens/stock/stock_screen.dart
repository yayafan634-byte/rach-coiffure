import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/perruque.dart';
import '../../navigation/app_section.dart';
import '../../services/caisse_service.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/export_csv.dart';
import '../../utils/format.dart';
import '../../utils/journal.dart';
import '../../utils/photo_image.dart';
import '../../utils/photo_store.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_pill.dart';
import '../caisse/caisse_screen.dart';
import '../caisse/vente_detail_screen.dart';
import 'mouvements_screen.dart';
import 'stock_form_screen.dart';

class StockScreen extends StatefulWidget {
  final bool filtreStockBasInitial;

  const StockScreen({super.key, this.filtreStockBasInitial = false});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Perruque> _tous = [];
  String _recherche = '';
  bool _filtreStockBas = false;
  String _tri = 'nom';
  bool _chargement = true;
  bool _modeSelection = false;
  final Set<int> _selection = {};
  final _searchCtrl = TextEditingController();

  List<Perruque> get _articlesSelectionnes =>
      _tous.where((p) => _selection.contains(p.id)).toList();

  double get _totalSelection =>
      _articlesSelectionnes.fold<double>(0, (s, p) => s + p.prixVente);

  List<Perruque> get _perruques {
    final q = _recherche.toLowerCase();
    final resultat = _tous.where((p) {
      final correspond = q.isEmpty ||
          p.nom.toLowerCase().contains(q) ||
          p.type.toLowerCase().contains(q) ||
          p.couleur.toLowerCase().contains(q) ||
          p.texture.toLowerCase().contains(q);
      return correspond && (!_filtreStockBas || p.stockBas);
    }).toList();

    resultat.sort((a, b) {
      return switch (_tri) {
        'quantite' => a.quantite.compareTo(b.quantite),
        'prix' => b.prixVente.compareTo(a.prixVente),
        'valeur' =>
          (b.quantite * b.prixVente).compareTo(a.quantite * a.prixVente),
        _ => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
      };
    });
    return resultat;
  }

  @override
  void initState() {
    super.initState();
    _filtreStockBas = widget.filtreStockBasInitial;
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
      final res = await db.query('perruques', orderBy: 'nom');
      if (!mounted) return;
      setState(() {
        _tous = res.map(Perruque.fromMap).toList();
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargement = false);
      showAppSnack(
        context,
        'Impossible de charger le stock.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _supprimer(Perruque p) async {
    if (!context.read<AuthProvider>().peut('suppressions')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Suppression non autorisée pour ce compte.'),
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
    await db.transaction((txn) async {
      await txn.delete(
        'mouvements_stock',
        where: 'perruqueId = ?',
        whereArgs: [p.id],
      );
      await txn.delete('perruques', where: 'id = ?', whereArgs: [p.id]);
    });
    await deletePhoto(p.photoPath);
    if (!mounted) return;
    await journaliser(
      context,
      'Article supprimé',
      details: '${p.nom} • ${p.quantite} en stock',
    );
    if (!mounted) return;
    showAppSnack(
      context,
      'Article supprimé.',
      type: AppSnackType.success,
    );
    _charger();
  }

  Future<void> _exporter() async {
    if (!context.read<AuthProvider>().peut('exports')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Export non autorisé pour ce compte.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    await exporterCsv(
      nomFichier: 'stock_perruques',
      entetes: const [
        'Nom',
        'Type',
        'Longueur',
        'Couleur',
        'Texture',
        'Quantite',
        'PrixAchat',
        'PrixVente',
        'ValeurAchat'
      ],
      lignes: _perruques
          .map((p) => [
                p.nom,
                p.type,
                p.longueur,
                p.couleur,
                p.texture,
                p.quantite,
                p.prixAchat,
                p.prixVente,
                (p.quantite * p.prixAchat).toStringAsFixed(0),
              ])
          .toList(),
    );
    if (!mounted) return;
    await journaliser(
      context,
      'Export du stock',
      details: '${_perruques.length} article(s) exporté(s) en CSV',
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

  void _activerSelection() {
    setState(() => _modeSelection = true);
  }

  void _annulerSelection() {
    setState(() {
      _modeSelection = false;
      _selection.clear();
    });
  }

  void _basculerSelection(Perruque p) {
    if (p.quantite <= 0) {
      showAppSnack(
        context,
        '${p.nom} est en rupture de stock.',
        type: AppSnackType.error,
      );
      return;
    }
    setState(() {
      if (!_selection.remove(p.id)) _selection.add(p.id!);
    });
  }

  Future<void> _encaisserSelection() async {
    final articles = _articlesSelectionnes;
    if (articles.isEmpty) return;

    final lignes = articles
        .map(
          (p) => LignePanier(
            perruqueId: p.id,
            libelle: p.nom,
            prixUnitaire: p.prixVente,
          ),
        )
        .toList();
    final vente = await ouvrirEncaissement(context, lignes: lignes);
    if (vente == null || !mounted) return;

    setState(() {
      _modeSelection = false;
      _selection.clear();
    });
    await _charger();
    if (!mounted) return;
    showAppSnack(
      context,
      'Vente #${vente.id} enregistrée.',
      type: AppSnackType.success,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VenteDetailScreen(vente: vente)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.peut('stock')) {
      return const AccesRefuse(
        message: 'La gestion du stock n\'est pas autorisée pour ce compte.',
      );
    }
    final estAdmin = auth.isAdmin;
    final peutSupprimer = auth.peut('suppressions');
    final nbStockBas = _tous.where((p) => p.stockBas).length;
    final valeur =
        _tous.fold<double>(0, (s, p) => s + p.quantite * p.prixAchat);
    final filtrees = _perruques;

    return AppShell(
      section: AppSection.stock,
      title: 'Stock perruques',
      actions: [
        if (nbStockBas > 0)
          IconButton(
            tooltip: 'Alerte stock bas ($nbStockBas)',
            icon: Badge.count(
              count: nbStockBas,
              child: const Icon(Icons.warning_amber_rounded),
            ),
            onPressed: () => setState(() => _filtreStockBas = true),
          ),
        IconButton(
          tooltip: _modeSelection
              ? 'Annuler la sélection'
              : 'Sélectionner des articles pour la caisse',
          icon: Icon(
            _modeSelection ? Icons.close_rounded : Icons.checklist_rounded,
          ),
          onPressed: _modeSelection ? _annulerSelection : _activerSelection,
        ),
        IconButton(
          tooltip: 'Historique du stock',
          icon: const Icon(Icons.history_rounded),
          onPressed: () async {
            await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MouvementsScreen()));
            _charger();
          },
        ),
        if (auth.peut('exports'))
          IconButton(
            tooltip: 'Exporter en CSV',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _exporter,
          ),
        const SizedBox(width: 4),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Article'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
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
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Tous'),
                            selected: !_filtreStockBas,
                            onSelected: (_) =>
                                setState(() => _filtreStockBas = false),
                          ),
                          FilterChip(
                            label: Text('Stock bas ($nbStockBas)'),
                            selected: _filtreStockBas,
                            selectedColor: AppColors.dangerSoft,
                            onSelected: (selectionne) => setState(
                              () => _filtreStockBas = selectionne,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Trier',
                      initialValue: _tri,
                      icon: const Icon(Icons.sort_rounded,
                          color: AppColors.slate700),
                      onSelected: (valeur) => setState(() => _tri = valeur),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'nom', child: Text('Nom (A-Z)')),
                        PopupMenuItem(
                          value: 'quantite',
                          child: Text('Quantité croissante'),
                        ),
                        PopupMenuItem(
                          value: 'prix',
                          child: Text('Prix décroissant'),
                        ),
                        PopupMenuItem(
                          value: 'valeur',
                          child: Text('Valeur du stock'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtrees.length} article(s)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              if (estAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
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
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: filtrees.length,
                                  itemBuilder: (ctx, i) =>
                                      _carteArticle(filtrees[i], peutSupprimer),
                                ),
                              ),
              ),
              if (_modeSelection) _barreSelection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barreSelection() {
    final nombre = _selection.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$nombre article(s) sélectionné(s)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.plum,
                    ),
                  ),
                  Text(
                    formatFcfa(_totalSelection),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: nombre == 0 ? null : _encaisserSelection,
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              label: const Text('Encaisser'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteArticle(Perruque p, bool peutSupprimer) {
    final selectionne = _selection.contains(p.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selectionne ? AppColors.roseSoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selectionne ? AppColors.rose : AppColors.line,
          ),
        ),
        child: InkWell(
          onTap: _modeSelection
              ? () => _basculerSelection(p)
              : () => _ouvrirFormulaire(perruque: p),
          onLongPress: _modeSelection
              ? null
              : () {
                  _activerSelection();
                  _basculerSelection(p);
                },
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
                          Flexible(child: _badgeStock(p)),
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
                if (_modeSelection)
                  Checkbox(
                    value: selectionne,
                    onChanged: (_) => _basculerSelection(p),
                  )
                else
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
                      if (peutSupprimer)
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
    final icone = rupture
        ? Icons.error_outline_rounded
        : bas
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded;

    return StatusPill(
      label: texte,
      color: accent,
      background: fond,
      icon: icone,
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
