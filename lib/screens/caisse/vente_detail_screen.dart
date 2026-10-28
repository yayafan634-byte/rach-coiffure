import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/perruque.dart';
import '../../models/vente.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

class VenteDetailScreen extends StatefulWidget {
  final Vente vente;
  const VenteDetailScreen({super.key, required this.vente});

  @override
  State<VenteDetailScreen> createState() => _VenteDetailScreenState();
}

class _VenteDetailScreenState extends State<VenteDetailScreen> {
  Client? _client;
  Perruque? _perruque;
  bool _chargement = true;

  static const _modes = {
    'especes': 'Espèces',
    'orange_money': 'Orange Money',
    'moov_money': 'Moov Money',
    'mix_yas': 'Mix by Yas',
  };

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final db = await DbHelper.instance.db;
    if (widget.vente.clientId != null) {
      final res = await db.query('clients',
          where: 'id = ?', whereArgs: [widget.vente.clientId]);
      if (res.isNotEmpty) _client = Client.fromMap(res.first);
    }
    if (widget.vente.perruqueId != null) {
      final res = await db.query('perruques',
          where: 'id = ?', whereArgs: [widget.vente.perruqueId]);
      if (res.isNotEmpty) _perruque = Perruque.fromMap(res.first);
    }
    if (!mounted) return;
    setState(() => _chargement = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vente;
    return Scaffold(
      appBar: AppBar(title: const Text('Reçu de vente')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Salon Perruques BF',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Reçu de caisse',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      _ligne('N°', '#${v.id ?? '-'}'),
                      _ligne('Date', formatDateHeure(v.dateVente)),
                      _ligne('Heure', formatHeure(v.dateVente)),
                      _ligne('Mode de paiement', _modes[v.modePaiement] ?? v.modePaiement),
                      if (_client != null) ...[
                        const SizedBox(height: 8),
                        _ligne('Client', _client!.nom),
                        _ligne('Téléphone', _client!.telephone),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      if (_perruque != null) ...[
                        _ligne('Article', _perruque!.nom),
                        _ligne('Quantité', '${v.quantite}'),
                        _ligne('Détails', '${_perruque!.type} • ${_perruque!.longueur} • ${_perruque!.couleur}'),
                      ] else
                        _ligne('Type', 'Vente libre'),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'MONTANT TOTAL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.plum,
                            ),
                          ),
                          Text(
                            formatFcfa(v.montant),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.roseDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Merci de votre confiance',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _ligne(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.plum,
            ),
          ),
        ],
      ),
    );
  }
}
