import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/perruque.dart';
import '../../models/vente.dart';
import '../../navigation/app_section.dart';
import '../../services/caisse_service.dart';
import '../../services/cloud_sync.dart';
import '../../services/parametres_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/son.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'vente_detail_screen.dart';

const _modes = {
  'especes': 'Espèces',
  'orange_money': 'Orange Money',
  'moov_money': 'Moov Money',
  'mix_yas': 'Mix by Yas',
};

const _icones = {
  'especes': Icons.payments_outlined,
  'orange_money': Icons.phone_iphone_rounded,
  'moov_money': Icons.smartphone_rounded,
  'mix_yas': Icons.credit_card_rounded,
};

Future<Vente?> ouvrirEncaissement(
  BuildContext context, {
  List<LignePanier> lignes = const [],
}) async {
  final db = await DbHelper.instance.db;
  final res =
      await db.query('perruques', where: 'quantite > 0', orderBy: 'nom');
  final perruquesDispo = res.map(Perruque.fromMap).toList();
  final clientsRes = await db.query('clients', orderBy: 'nom');
  final clients = clientsRes.map(Client.fromMap).toList();
  final parametres = await ParametresService.instance.charger();
  if (!context.mounted) return null;

  final auth = context.read<AuthProvider>();
  return showAppSheet<Vente>(
    context,
    builder: (_) => EncaissementSheet(
      perruques: perruquesDispo,
      clients: clients,
      parametres: parametres,
      userId: auth.user?.id,
      utilisateur: auth.user?.nom,
      lignesInitiales: lignes,
    ),
  );
}

class CaisseScreen extends StatefulWidget {
  const CaisseScreen({super.key});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends State<CaisseScreen> {
  List<Vente> _ventes = [];
  final Map<int, String> _descriptions = {};
  double _totalJour = 0;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final db = await DbHelper.instance.db;
      final today = DateTime.now();
      final debut =
          DateTime(today.year, today.month, today.day).toIso8601String();
      final fin = DateTime(today.year, today.month, today.day)
          .add(const Duration(days: 1))
          .toIso8601String();

      final res = await db.query('ventes',
          where: 'dateVente >= ? AND dateVente < ?',
          whereArgs: [debut, fin],
          orderBy: 'dateVente DESC');

      final itemsRes = await db.rawQuery('''
        SELECT vi.venteId,
               GROUP_CONCAT(COALESCE(p.nom, vi.libelle, 'Article'), ', ')
                 AS description
        FROM venteItems vi
        JOIN ventes v ON v.id = vi.venteId
        LEFT JOIN perruques p ON p.id = vi.perruqueId
        WHERE v.dateVente >= ? AND v.dateVente < ?
        GROUP BY vi.venteId
      ''', [debut, fin]);

      final descriptions = <int, String>{
        for (final ligne in itemsRes)
          (ligne['venteId'] as num).toInt():
              (ligne['description'] as String?) ?? '',
      };
      final total =
          res.fold<double>(0, (s, m) => s + (m['montant'] as num).toDouble());

      if (!mounted) return;
      setState(() {
        _ventes = res.map(Vente.fromMap).toList();
        _descriptions
          ..clear()
          ..addAll(descriptions);
        _totalJour = total;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargement = false);
      showAppSnack(
        context,
        'Impossible de charger les ventes du jour.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _encaisser() async {
    final vente = await ouvrirEncaissement(context);
    if (vente == null || !mounted) return;

    CloudSync.instance.pushMaintenant();
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
    if (!auth.peut('caisse')) {
      return const AccesRefuse(
        message: 'L\'encaissement n\'est pas autorisé pour ce compte.',
      );
    }

    return AppShell(
      section: AppSection.caisse,
      title: 'Caisse',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _encaisser,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Encaisser'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.roseDeep, AppColors.rose],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.rose.withValues(alpha: 0.26),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total du jour',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatFcfa(_totalJour),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_ventes.length} vente(s) aujourd\'hui',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Paramètres du reçu',
                          onPressed: () => _ouvrirParametres(),
                          icon: Icon(
                            Icons.tune_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SectionHeader(title: 'Ventes du jour'),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _ventes.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Aucune vente aujourd\'hui',
                          message:
                              'Les encaissements du jour apparaîtront ici.',
                          actionLabel: 'Encaisser',
                          onAction: _encaisser,
                        )
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: AppColors.rose,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _ventes.length,
                            itemBuilder: (ctx, i) => _carteVente(_ventes[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _ouvrirParametres() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Paramètres')),
          body: const Center(
            child: Text('Disponible depuis le menu Administration.'),
          ),
        ),
      ),
    );
  }

  Widget _carteVente(Vente v) {
    final (accent, fond) = switch (v.modePaiement) {
      'orange_money' => (const Color(0xFFB96A1F), const Color(0xFFFCEEDD)),
      'moov_money' => (const Color(0xFF2F6E9E), const Color(0xFFE4EFF7)),
      'mix_yas' => (const Color(0xFF6A4C93), const Color(0xFFEFE8F7)),
      _ => (AppColors.success, AppColors.successSoft),
    };
    final description = _descriptions[v.id]?.trim();
    final libelle = v.libelle?.trim();
    final type = description != null && description.isNotEmpty
        ? description
        : (v.perruqueId != null
            ? 'Perruque${v.quantite > 1 ? ' ×${v.quantite}' : ''}'
            : (libelle != null && libelle.isNotEmpty
                ? libelle
                : 'Vente libre'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => VenteDetailScreen(vente: v),
                ),
              )
              .then((_) => _charger()),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fond,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _icones[v.modePaiement] ?? Icons.payments_outlined,
                    size: 19,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatFcfa(v.montant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_modes[v.modePaiement] ?? v.modePaiement} • $type',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatHeure(v.dateVente),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Icon(Icons.receipt_long_outlined,
                        size: 16, color: AppColors.muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EncaissementSheet extends StatefulWidget {
  final List<Perruque> perruques;
  final List<Client> clients;
  final Parametres parametres;
  final int? userId;
  final String? utilisateur;
  final List<LignePanier> lignesInitiales;

  const EncaissementSheet({
    super.key,
    required this.perruques,
    required this.clients,
    required this.parametres,
    this.userId,
    this.utilisateur,
    this.lignesInitiales = const [],
  });

  @override
  State<EncaissementSheet> createState() => EncaissementSheetState();
}

class EncaissementSheetState extends State<EncaissementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qteCtrl = TextEditingController(text: '1');
  final _libelleCtrl = TextEditingController();
  final _montantLibreCtrl = TextEditingController();
  final _remiseCtrl = TextEditingController(text: '0');
  final _pointsCtrl = TextEditingController(text: '0');

  String _type = 'perruque';
  String _mode = 'especes';
  Perruque? _perruque;
  Client? _client;
  final List<LignePanier> _panier = [];
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    if (widget.perruques.isNotEmpty) {
      _perruque = widget.perruques.first;
    }
    _panier.addAll(widget.lignesInitiales);
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    _libelleCtrl.dispose();
    _montantLibreCtrl.dispose();
    _remiseCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  double get _sousTotal =>
      _panier.fold<double>(0, (s, ligne) => s + ligne.total);

  double get _remise =>
      double.tryParse(_remiseCtrl.text.trim().replaceAll(',', '.')) ?? 0;

  int get _pointsMax {
    final dispo = _client?.pointsFidelite ?? 0;
    if (dispo <= 0 || widget.parametres.valeurPoint <= 0) return 0;
    final marge = math.max(0.0, _sousTotal - _remise);
    final maxParMontant = (marge / widget.parametres.valeurPoint).floor();
    return math.min(dispo, maxParMontant);
  }

  int get _pointsUtilises {
    final saisi = int.tryParse(_pointsCtrl.text.trim()) ?? 0;
    if (saisi < 0) return 0;
    return math.min(saisi, _pointsMax);
  }

  double get _pointsRemise => _pointsUtilises * widget.parametres.valeurPoint;

  double get _net {
    final valeur = _sousTotal - _remise - _pointsRemise;
    return valeur < 0 ? 0 : valeur;
  }

  int _stockRestant(Perruque p) {
    final dansPanier = _panier
        .where((l) => l.perruqueId == p.id)
        .fold<int>(0, (s, l) => s + l.quantite);
    return p.quantite - dansPanier;
  }

  void _ajouterPerruque() {
    final p = _perruque;
    if (p == null) {
      showAppSnack(context, 'Choisissez une perruque.',
          type: AppSnackType.error);
      return;
    }
    final qte = int.tryParse(_qteCtrl.text.trim()) ?? 0;
    if (qte <= 0) {
      showAppSnack(context, 'Quantité invalide.', type: AppSnackType.error);
      return;
    }
    if (qte > _stockRestant(p)) {
      showAppSnack(
        context,
        'Stock insuffisant (${_stockRestant(p)} disponible(s)).',
        type: AppSnackType.error,
      );
      return;
    }

    setState(() {
      final index = _panier.indexWhere((l) => l.perruqueId == p.id);
      if (index >= 0) {
        final ligne = _panier[index];
        _panier[index] = ligne.copyWith(quantite: ligne.quantite + qte);
      } else {
        _panier.add(LignePanier(
          perruqueId: p.id,
          libelle: p.nom,
          prixUnitaire: p.prixVente,
          quantite: qte,
        ));
      }
      _qteCtrl.text = '1';
    });
  }

  void _ajouterLibre() {
    final libelle = _libelleCtrl.text.trim();
    final montant =
        double.tryParse(_montantLibreCtrl.text.trim().replaceAll(',', '.'));
    if (montant == null || montant <= 0) {
      showAppSnack(context, 'Montant invalide.', type: AppSnackType.error);
      return;
    }
    setState(() {
      _panier.add(LignePanier(
        libelle: libelle.isEmpty ? 'Prestation' : libelle,
        prixUnitaire: montant,
      ));
      _libelleCtrl.clear();
      _montantLibreCtrl.clear();
    });
  }

  Future<void> _valider() async {
    if (_panier.isEmpty) {
      showAppSnack(context, 'Ajoutez au moins un article.',
          type: AppSnackType.error);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_remise < 0 || _remise > _sousTotal) {
      showAppSnack(context, 'Remise invalide.', type: AppSnackType.error);
      return;
    }
    if (_pointsUtilises > _pointsMax) {
      showAppSnack(
        context,
        'Le client ne peut utiliser que $_pointsMax point(s).',
        type: AppSnackType.error,
      );
      return;
    }

    setState(() => _enregistrement = true);
    try {
      final vente = await CaisseService.instance.vendre(
        lignes: _panier,
        modePaiement: _mode,
        clientId: _client?.id,
        remise: _remise,
        pointsUtilises: _pointsUtilises,
        valeurPoint: widget.parametres.valeurPoint,
        userId: widget.userId,
        utilisateur: widget.utilisateur,
      );
      if (!mounted) return;
      SonService.instance.succes();
      Navigator.of(context).pop(vente);
    } on CaisseException catch (e) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      showAppSnack(context, e.message, type: AppSnackType.error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      showAppSnack(
        context,
        'Impossible d\'enregistrer l\'encaissement.',
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Encaisser',
            subtitle: 'Panier multi-articles, remise et points fidélité.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Client?>(
            initialValue: _client,
            isExpanded: true,
            items: [
              const DropdownMenuItem<Client?>(
                value: null,
                child: Text('Sans client'),
              ),
              ...widget.clients.map((c) => DropdownMenuItem<Client?>(
                    value: c,
                    child: Text(
                      '${c.nom} • ${c.pointsFidelite} pt(s)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (v) => setState(() {
              _client = v;
              if (_pointsMax == 0) _pointsCtrl.text = '0';
            }),
            decoration: const InputDecoration(
              labelText: 'Client (facultatif)',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_basket_outlined,
                        size: 18, color: AppColors.rose),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Panier',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                    ),
                    Text(
                      '${_panier.length} ligne(s)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_panier.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Ajoutez une perruque ou une prestation libre.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  )
                else
                  for (var i = 0; i < _panier.length; i++)
                    _lignePanier(i, _panier[i]),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'perruque',
                      label: Text('Perruque'),
                      icon: Icon(Icons.content_cut, size: 15),
                    ),
                    ButtonSegment(
                      value: 'libre',
                      label: Text('Libre'),
                      icon: Icon(Icons.receipt_long_outlined, size: 15),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (v) => setState(() => _type = v.first),
                ),
                const SizedBox(height: 12),
                if (_type == 'perruque') ...[
                  if (widget.perruques.isEmpty)
                    const Text(
                      'Aucune perruque en stock. Utilisez une ligne libre.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    )
                  else ...[
                    DropdownButtonFormField<Perruque>(
                      initialValue: _perruque,
                      isExpanded: true,
                      items: widget.perruques
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  '${p.nom} (${_stockRestant(p)} dispo.)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _perruque = v),
                      decoration: const InputDecoration(
                        labelText: 'Perruque',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qteCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: FilledButton.icon(
                            onPressed: _ajouterPerruque,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Ajouter'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  TextFormField(
                    controller: _libelleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Libellé',
                      prefixIcon: Icon(Icons.notes_rounded),
                      hintText: 'Ex: Coiffure, tissage...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _montantLibreCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Montant (FCFA)',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FilledButton.icon(
                          onPressed: _ajouterLibre,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.roseSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _totalLigne('Sous-total', _sousTotal),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Remise',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.roseDeep,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        controller: _remiseCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.right,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          isDense: true,
                          suffixText: 'FCFA',
                        ),
                        validator: (v) {
                          final n = double.tryParse(
                              (v ?? '').trim().replaceAll(',', '.'));
                          if (n == null || n < 0) return 'Invalide';
                          if (n > _sousTotal) return 'Trop élevé';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Points fidélité',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.roseDeep,
                            ),
                          ),
                          Text(
                            _client == null
                                ? 'Sélectionnez un client'
                                : '${_client!.pointsFidelite} dispo • '
                                    '1 pt = ${formatFcfa(widget.parametres.valeurPoint)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        controller: _pointsCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        enabled: _client != null && _client!.pointsFidelite > 0,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          suffixText: 'max $_pointsMax',
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) return 'Invalide';
                          if (n > _pointsMax) return 'Max $_pointsMax';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'NET À PAYER',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.roseDeep,
                        ),
                      ),
                    ),
                    Text(
                      formatFcfa(_net),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.roseDeep,
                      ),
                    ),
                  ],
                ),
                if (_pointsUtilises > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'dont -${formatFcfa(_pointsRemise)} de points',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mode de paiement',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.plum,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _modes.entries.map((e) {
              final selectionne = _mode == e.key;
              return ChoiceChip(
                avatar: Icon(
                  _icones[e.key],
                  size: 16,
                  color: selectionne ? AppColors.roseDeep : AppColors.muted,
                ),
                label: Text(e.value),
                selected: selectionne,
                onSelected: (_) => setState(() => _mode = e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _enregistrement ? null : _valider,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _enregistrement
                    ? 'Enregistrement...'
                    : 'Valider l\'encaissement',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lignePanier(int index, LignePanier ligne) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.line),
            ),
            alignment: Alignment.center,
            child: Text(
              '${ligne.quantite}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.plum,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ligne.libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.plum,
                  ),
                ),
                Text(
                  '${formatFcfa(ligne.prixUnitaire)} × ${ligne.quantite}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatFcfa(ligne.total),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.roseDeep,
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _panier.removeAt(index)),
            icon: const Icon(Icons.close_rounded,
                size: 17, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _totalLigne(String label, double valeur) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.roseDeep),
          ),
        ),
        Text(
          formatFcfa(valeur),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.roseDeep,
          ),
        ),
      ],
    );
  }
}
