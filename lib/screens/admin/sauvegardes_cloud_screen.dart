import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../navigation/app_section.dart';
import '../../services/cloud_sync.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/journal.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';

class SauvegardesCloudScreen extends StatefulWidget {
  const SauvegardesCloudScreen({super.key});

  @override
  State<SauvegardesCloudScreen> createState() => _SauvegardesCloudScreenState();
}

class _SauvegardesCloudScreenState extends State<SauvegardesCloudScreen> {
  List<CloudSnapshot> _snapshots = [];
  bool _chargement = true;
  String? _erreur;
  String? _enCours;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (mounted) setState(() => _chargement = true);
    try {
      final liste = await CloudSync.instance.historique();
      if (!mounted) return;
      setState(() {
        _snapshots = liste;
        _erreur = null;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger les sauvegardes. '
            'Vérifiez la connexion internet.';
        _chargement = false;
      });
    }
  }

  Future<void> _sauvegarder() async {
    if (_enCours != null) return;
    setState(() => _enCours = 'sauvegarde');
    final res = await CloudSync.instance.creerSauvegarde();
    if (!mounted) return;
    setState(() => _enCours = null);
    showAppSnack(
      context,
      res.message,
      type: res.ok ? AppSnackType.success : AppSnackType.error,
    );
    if (res.ok) {
      await journaliser(
        context,
        'Sauvegarde cloud créée',
        details: 'Instantané manuel des données du salon',
      );
      await _charger();
    }
  }

  Future<void> _restaurer(CloudSnapshot snap) async {
    if (_enCours != null) return;
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: Text(
          'Les données actuelles de cet appareil seront remplacées par la '
          'sauvegarde du ${snap.date == null ? 'date inconnue' : formatDateHeure(snap.date!)}. '
          'Cette version sera aussi envoyée aux autres appareils.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmer != true) return;

    setState(() => _enCours = snap.id);
    final res = await CloudSync.instance.restaurerSnapshot(snap.id);
    if (!mounted) return;
    setState(() => _enCours = null);
    showAppSnack(
      context,
      res.message,
      type: res.ok ? AppSnackType.success : AppSnackType.error,
    );
    if (res.ok) {
      await journaliser(
        context,
        'Restauration cloud',
        details:
            'Sauvegarde ${snap.id} du ${snap.date == null ? 'date inconnue' : formatDateHeure(snap.date!)}',
      );
      await _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return const AccesRefuse(
        message: 'Les sauvegardes cloud sont réservées à l\'administrateur.',
      );
    }

    return AppShell(
      section: AppSection.utilisateurs,
      title: 'Sauvegardes cloud',
      actions: [
        IconButton(
          tooltip: 'Rafraîchir',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _chargement ? null : _charger,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _charger,
        color: AppColors.rose,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _entete(),
            const SizedBox(height: 18),
            if (_chargement)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_erreur != null)
              _blocErreur()
            else if (_snapshots.isEmpty)
              EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Aucune sauvegarde',
                message:
                    'Créez une première sauvegarde cloud pour pouvoir restaurer vos données plus tard.',
                actionLabel: 'Sauvegarder maintenant',
                onAction: _sauvegarder,
              )
            else
              ..._snapshots.map(_carteSnapshot),
          ],
        ),
      ),
    );
  }

  Widget _entete() {
    final synchronisation = _enCours == 'sauvegarde';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF2F4), Color(0xFFFFFBF5)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.roseSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.cloud_done_outlined,
                  color: AppColors.roseDeep,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historique des versions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.plum,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Les 10 dernières versions sont conservées dans le cloud.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _enCours == null ? _sauvegarder : null,
              icon: synchronisation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.backup_outlined, size: 20),
              label: Text(
                synchronisation
                    ? 'Sauvegarde en cours...'
                    : 'Sauvegarder maintenant',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blocErreur() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _erreur ?? 'Erreur inconnue.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.slate900,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: _charger,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _carteSnapshot(CloudSnapshot snap) {
    final enCours = _enCours == snap.id;
    final date = snap.date;
    final libelle = date == null ? 'Date inconnue' : formatDateHeure(date);
    final elements = snap.poids == 1 ? '1 élément' : '${snap.poids} éléments';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libelle,
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
                    elements,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            enCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _enCours == null ? () => _restaurer(snap) : null,
                    child: const Text('Restaurer'),
                  ),
          ],
        ),
      ),
    );
  }
}
