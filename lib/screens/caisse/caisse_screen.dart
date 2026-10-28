import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/perruque.dart';
import '../../models/vente.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'vente_detail_screen.dart';

class CaisseScreen extends StatefulWidget {
  const CaisseScreen({super.key});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends State<CaisseScreen> {
  List<Vente> _ventes = [];
  double _totalJour = 0;
  bool _chargement = true;

  static const _modes = {
    'especes': 'Espèces',
    'orange_money': 'Orange Money',
    'moov_money': 'Moov Money',
    'mix_yas': 'Mix by Yas',
  };

  static const _icones = {
    'especes': Icons.payments_outlined,
    'orange_money': Icons.phone_iphone_rounded,
    'moov_money': Icons.smartphone_rounded,
    'mix_yas': Icons.credit_card_rounded,
  };

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final db = await DbHelper.instance.db;
    final today = DateTime.now();
    final debut = DateTime(today.year, today.month, today.day).toIso8601String();

    final res = await db.query('ventes',
        where: 'dateVente >= ?', whereArgs: [debut], orderBy: 'dateVente DESC');

    final total =
        res.fold<double>(0, (s, m) => s + (m['montant'] as num).toDouble());

    if (!mounted) return;
    setState(() {
      _ventes = res.map(Vente.fromMap).toList();
      _totalJour = total;
      _chargement = false;
    });
  }

  Future<void> _encaisser() async {
    final montantCtrl = TextEditingController();
    final qteCtrl = TextEditingController(text: '1');
    final libelleCtrl = TextEditingController();
    String mode = 'especes';
    String typeVente = 'perruque';
    Perruque? perruqueChoisie;
    Client? clientChoisi;
    final formKey = GlobalKey<FormState>();

    final db = await DbHelper.instance.db;
    final res = await db.query('perruques',
        where: 'quantite > 0', orderBy: 'nom');
    final perruquesDispo = res.map(Perruque.fromMap).toList();
    if (perruquesDispo.isNotEmpty) perruqueChoisie = perruquesDispo.first;

    final clientsRes = await db.query('clients', orderBy: 'nom');
    final clients = clientsRes.map(Client.fromMap).toList();

    void majMontant(StateSetter setSheet) {
      if (typeVente != 'perruque' || perruqueChoisie == null) return;
      final qte = int.tryParse(qteCtrl.text) ?? 1;
      montantCtrl.text =
          (perruqueChoisie!.prixVente * qte).toStringAsFixed(0);
      setSheet(() {});
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final montant = double.tryParse(
                  montantCtrl.text.trim().replaceAll(',', '.')) ??
              0;

          return Padding(
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
                            'Encaisser',
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
                      'Enregistrez une vente de perruque ou un encaissement libre.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'perruque',
                          label: Text('Perruque'),
                          icon: Icon(Icons.content_cut, size: 16),
                        ),
                        ButtonSegment(
                          value: 'libre',
                          label: Text('Libre'),
                          icon: Icon(Icons.receipt_long_outlined, size: 16),
                        ),
                      ],
                      selected: {typeVente},
                      onSelectionChanged: (valeurs) => setSheet(() {
                        typeVente = valeurs.first;
                        if (typeVente == 'perruque') {
                          majMontant(setSheet);
                        }
                      }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Client?>(
                      initialValue: clientChoisi,
                      items: [
                        const DropdownMenuItem<Client?>(
                          value: null,
                          child: Text('Sans client'),
                        ),
                        ...clients.map((c) => DropdownMenuItem<Client?>(
                              value: c,
                              child: Text(
                                '${c.nom} • ${c.telephone}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (v) => setSheet(() => clientChoisi = v),
                      decoration: const InputDecoration(
                        labelText: 'Client (facultatif)',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (typeVente == 'perruque') ...[
                      if (perruquesDispo.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Aucune perruque en stock. Utilisez l\'encaissement libre.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.warning,
                            ),
                          ),
                        )
                      else ...[
                        DropdownButtonFormField<Perruque>(
                          initialValue: perruqueChoisie,
                          items: perruquesDispo
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(
                                      '${p.nom} (${p.quantite} dispo.)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) => setSheet(() {
                            perruqueChoisie = v;
                            majMontant(setSheet);
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Perruque',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: qteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantité',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          onChanged: (_) => majMontant(setSheet),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Quantité invalide';
                            if (perruqueChoisie != null &&
                                n > perruqueChoisie!.quantite) {
                              return 'Stock insuffisant (${perruqueChoisie!.quantite})';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    if (typeVente == 'libre') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: libelleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Libellé (facultatif)',
                          prefixIcon: Icon(Icons.notes_rounded),
                          hintText: 'Ex: Coiffure, tissage...',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: montantCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setSheet(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Montant (FCFA)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (v) {
                        final n = double.tryParse(
                            (v ?? '').trim().replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Montant invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
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
                        final selectionne = mode == e.key;
                        return ChoiceChip(
                          avatar: Icon(
                            _icones[e.key],
                            size: 16,
                            color: selectionne
                                ? AppColors.roseDeep
                                : AppColors.muted,
                          ),
                          label: Text(e.value),
                          selected: selectionne,
                          onSelected: (_) => setSheet(() => mode = e.key),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.roseSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'À encaisser',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.roseDeep,
                              ),
                            ),
                          ),
                          Text(
                            formatFcfa(montant),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.roseDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final valeur = double.parse(
                              montantCtrl.text.trim().replaceAll(',', '.'));

                          String? erreur;
                          if (typeVente == 'perruque') {
                            if (perruqueChoisie == null) {
                              erreur = 'Choisissez une perruque';
                            } else {
                              erreur = await StockService.instance
                                  .vendreAvecStock(
                                perruqueId: perruqueChoisie!.id!,
                                quantite: int.parse(qteCtrl.text),
                                montant: valeur,
                                modePaiement: mode,
                              );
                              if (erreur == null && clientChoisi?.id != null) {
                                final db2 = await DbHelper.instance.db;
                                final pts = (valeur / 1000).floor();
                                if (pts > 0) {
                                  await db2.rawUpdate(
                                    'UPDATE clients SET pointsFidelite = pointsFidelite + ? WHERE id = ?',
                                    [pts, clientChoisi!.id!],
                                  );
                                }
                              }
                            }
                          } else {
                            final db = await DbHelper.instance.db;
                            await db.insert(
                              'ventes',
                              Vente(
                                clientId: clientChoisi?.id,
                                montant: valeur,
                                modePaiement: mode,
                              ).toMap(),
                            );
                            if (clientChoisi?.id != null) {
                              final pts = (valeur / 1000).floor();
                              if (pts > 0) {
                                await db.rawUpdate(
                                  'UPDATE clients SET pointsFidelite = pointsFidelite + ? WHERE id = ?',
                                  [pts, clientChoisi!.id!],
                                );
                              }
                            }
                          }

                          if (!ctx.mounted) return;
                          if (erreur != null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(erreur),
                              backgroundColor: AppColors.danger,
                            ));
                            return;
                          }
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Encaissement enregistré.'),
                            ),
                          );
                          _charger();
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Valider l\'encaissement'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caisse')),
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
                                  color:
                                      Colors.white.withValues(alpha: 0.80),
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
                                  color:
                                      Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
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
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 96),
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

  Widget _carteVente(Vente v) {
    final (accent, fond) = switch (v.modePaiement) {
      'orange_money' => (const Color(0xFFB96A1F), const Color(0xFFFCEEDD)),
      'moov_money' => (const Color(0xFF2F6E9E), const Color(0xFFE4EFF7)),
      'mix_yas' => (const Color(0xFF6A4C93), const Color(0xFFEFE8F7)),
      _ => (AppColors.success, AppColors.successSoft),
    };

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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VenteDetailScreen(vente: v)),
          ),
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
                        '${_modes[v.modePaiement] ?? v.modePaiement} • ${v.perruqueId != null ? 'Perruque' : 'Vente libre'}',
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
