import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/rendez_vous.dart';
import '../../navigation/app_section.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/id.dart';
import '../../utils/journal.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../clients/clients_screen.dart';

class RdvScreen extends StatefulWidget {
  const RdvScreen({super.key});

  @override
  State<RdvScreen> createState() => _RdvScreenState();
}

class _RdvScreenState extends State<RdvScreen> {
  List<RendezVous> _rdvs = [];
  List<Client> _clients = [];
  bool _chargement = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final db = await DbHelper.instance.db;
      final rdvRes = await db.query('rendezVous', orderBy: 'dateHeure');
      final clientRes = await db.query('clients', orderBy: 'nom');
      if (!mounted) return;
      setState(() {
        _rdvs = rdvRes.map(RendezVous.fromMap).toList();
        _clients = clientRes.map(Client.fromMap).toList();
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargement = false);
      showAppSnack(
        context,
        'Impossible de charger les rendez-vous.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _ajouter() async {
    if (_clients.isEmpty) {
      showAppSnack(
        context,
        'Ajoutez d\'abord un client au répertoire.',
        type: AppSnackType.info,
        action: SnackBarAction(
          label: 'Clients',
          textColor: Colors.white,
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientsScreen()),
            );
            _charger();
          },
        ),
      );
      return;
    }

    var clientId = _clients.first.id!;
    var date = DateTime.now().add(const Duration(hours: 1));
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var enregistrement = false;

    final cree = await showAppSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
                  const SheetHeader(
                    title: 'Nouveau rendez-vous',
                    subtitle: 'Planifiez un rendez-vous pour un client.',
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<int>(
                    initialValue: clientId,
                    items: _clients
                        .map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.nom)))
                        .toList(),
                    onChanged: (v) => clientId = v!,
                    decoration: const InputDecoration(
                      labelText: 'Client',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.rose,
                      ),
                      title: const Text(
                        'Date et heure',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      subtitle: Text(
                        formatDateHeure(date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.plum,
                        ),
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d == null || !ctx.mounted) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(date),
                        );
                        if (t == null) return;
                        setSheet(() {
                          date = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note (optionnel)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: enregistrement
                          ? null
                          : () async {
                              if (date.isBefore(DateTime.now())) {
                                showAppSnack(
                                  ctx,
                                  'Choisissez une date et une heure à venir.',
                                  type: AppSnackType.error,
                                );
                                return;
                              }
                              setSheet(() => enregistrement = true);
                              try {
                                final db = await DbHelper.instance.db;
                                await db.insert(
                                  'rendezVous',
                                  RendezVous(
                                    id: nouvelId(),
                                    clientId: clientId,
                                    dateHeure: date,
                                    note: noteCtrl.text.trim().isEmpty
                                        ? null
                                        : noteCtrl.text.trim(),
                                  ).toMap(),
                                );
                              } catch (_) {
                                if (!ctx.mounted) return;
                                setSheet(() => enregistrement = false);
                                showAppSnack(
                                  ctx,
                                  'Impossible d\'enregistrer le rendez-vous.',
                                  type: AppSnackType.error,
                                );
                                return;
                              }
                              if (!ctx.mounted) return;
                              await journaliser(
                                ctx,
                                'Rendez-vous créé',
                                details:
                                    '${_nomClient(clientId)} • ${formatDateHeure(date)}',
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx, true);
                            },
                      icon: enregistrement
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.event_available_rounded,
                              size: 20,
                            ),
                      label: Text(
                        enregistrement
                            ? 'Enregistrement...'
                            : 'Enregistrer le rendez-vous',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    noteCtrl.dispose();
    if (cree == true) {
      _charger();
      if (mounted) {
        showAppSnack(
          context,
          'Rendez-vous enregistré.',
          type: AppSnackType.success,
        );
      }
    }
  }

  Future<void> _changerStatut(RendezVous r, String statut) async {
    try {
      final db = await DbHelper.instance.db;
      await db.update(
        'rendezVous',
        {'statut': statut},
        where: 'id = ?',
        whereArgs: [r.id],
      );
      if (!mounted) return;
      await journaliser(
        context,
        'Rendez-vous $statut',
        details: '${_nomClient(r.clientId)} • ${formatDateHeure(r.dateHeure)}',
      );
      await _charger();
      if (mounted) {
        showAppSnack(
          context,
          statut == 'terminé'
              ? 'Rendez-vous marqué terminé.'
              : statut == 'annulé'
                  ? 'Rendez-vous annulé.'
                  : 'Rendez-vous remis en prévu.',
          type: AppSnackType.success,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Impossible de mettre à jour le rendez-vous.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _supprimer(RendezVous r) async {
    if (!context.read<AuthProvider>().peut('suppressions')) {
      showAppSnack(
        context,
        'Suppression non autorisée pour ce compte.',
        type: AppSnackType.error,
      );
      return;
    }
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce rendez-vous ?'),
        content: Text(
            'Le rendez-vous de ${_nomClient(r.clientId)} sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmer != true) return;

    try {
      final db = await DbHelper.instance.db;
      await db.delete('rendezVous', where: 'id = ?', whereArgs: [r.id]);
      if (!mounted) return;
      await journaliser(
        context,
        'Rendez-vous supprimé',
        details: '${_nomClient(r.clientId)} • ${formatDateHeure(r.dateHeure)}',
      );
      await _charger();
      if (mounted) {
        showAppSnack(
          context,
          'Rendez-vous supprimé.',
          type: AppSnackType.success,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Impossible de supprimer le rendez-vous.',
        type: AppSnackType.error,
      );
    }
  }

  String _nomClient(int id) {
    final c = _clients.where((c) => c.id == id).toList();
    return c.isEmpty ? 'Client #$id' : c.first.nom;
  }

  Client? _clientDe(int id) {
    final c = _clients.where((c) => c.id == id).toList();
    return c.isEmpty ? null : c.first;
  }

  String _numeroWhatsApp(String brut) {
    var numero = brut.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.startsWith('00')) numero = numero.substring(2);
    if (numero.length == 8) return '226$numero';
    return numero;
  }

  Future<void> _rappelWhatsApp(RendezVous r) async {
    final client = _clientDe(r.clientId);
    final telephone = client?.telephone.trim() ?? '';
    if (telephone.isEmpty) {
      showAppSnack(
        context,
        'Aucun numéro de téléphone pour ce client.',
        type: AppSnackType.error,
      );
      return;
    }
    final numero = _numeroWhatsApp(telephone);
    if (numero.isEmpty) {
      showAppSnack(
        context,
        'Numéro de téléphone invalide.',
        type: AppSnackType.error,
      );
      return;
    }
    final nom = client?.nom ?? 'cliente';
    final texte = 'Bonjour $nom, rappel de votre rendez-vous au salon '
        'Rach Coiffure le ${formatDateHeure(r.dateHeure)}. '
        'Merci de nous prévenir en cas d\'empêchement.';
    final uri = Uri.parse(
      'https://wa.me/$numero?text=${Uri.encodeComponent(texte)}',
    );
    try {
      final ouvert = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ouvert && mounted) {
        showAppSnack(
          context,
          'Impossible d\'ouvrir WhatsApp.',
          type: AppSnackType.error,
        );
        return;
      }
      if (!mounted) return;
      await journaliser(
        context,
        'Rappel WhatsApp',
        details: '$nom • ${formatDateHeure(r.dateHeure)}',
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Impossible d\'ouvrir WhatsApp sur cet appareil.',
        type: AppSnackType.error,
      );
    }
  }

  List<RendezVous> _rdvDuJour(DateTime day) {
    final debut = DateTime(day.year, day.month, day.day);
    final fin = debut.add(const Duration(days: 1));
    return _rdvs
        .where((r) => !r.dateHeure.isBefore(debut) && r.dateHeure.isBefore(fin))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.peut('rdv')) {
      return const AccesRefuse(
        message:
            'La gestion des rendez-vous n\'est pas autorisée pour ce compte.',
      );
    }
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day);
    final debutDemain = debutJour.add(const Duration(days: 1));

    final aujourdHui = _rdvs
        .where((r) =>
            !r.dateHeure.isBefore(debutJour) &&
            r.dateHeure.isBefore(debutDemain))
        .toList();
    final aVenir =
        _rdvs.where((r) => !r.dateHeure.isBefore(debutDemain)).toList();
    final passes = _rdvs
        .where((r) => r.dateHeure.isBefore(debutJour))
        .toList()
        .reversed
        .toList();

    final rdvSelectionnes = _rdvDuJour(_selectedDay);
    final estAdmin = auth.isAdmin;

    return AppShell(
      section: AppSection.rdv,
      title: 'Rendez-vous',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.add_rounded),
        label: const Text('RDV'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _rdvs.isEmpty
              ? EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'Aucun rendez-vous',
                  message:
                      'Planifiez le premier rendez-vous du salon pour remplir votre agenda.',
                  actionLabel: 'Nouveau rendez-vous',
                  onAction: _ajouter,
                )
              : RefreshIndicator(
                  onRefresh: _charger,
                  color: AppColors.rose,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _resume(aujourdHui.length, aVenir.length),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: TableCalendar<RendezVous>(
                          firstDay: DateTime(now.year - 1),
                          lastDay: DateTime(now.year + 2),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          eventLoader: _rdvDuJour,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: true,
                            titleCentered: true,
                          ),
                          calendarStyle: const CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: AppColors.roseSoft,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: AppColors.rose,
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: BoxDecoration(
                              color: AppColors.roseDeep,
                              shape: BoxShape.circle,
                            ),
                          ),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: 'RDV du ${formatDate(_selectedDay)}',
                      ),
                      const SizedBox(height: 8),
                      if (rdvSelectionnes.isEmpty)
                        _blocVideCalendrier()
                      else
                        ...rdvSelectionnes.map((r) => _carteRdv(r, estAdmin)),
                      if (aujourdHui.isNotEmpty &&
                          !isSameDay(_selectedDay, now)) ...[
                        const SizedBox(height: 18),
                        const SectionHeader(title: "Aujourd'hui"),
                        const SizedBox(height: 8),
                        ...aujourdHui.map((r) => _carteRdv(r, estAdmin)),
                      ],
                      if (aVenir.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const SectionHeader(title: 'À venir'),
                        const SizedBox(height: 8),
                        ...aVenir.take(5).map((r) => _carteRdv(r, estAdmin)),
                      ],
                      if (passes.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const SectionHeader(title: 'Passés'),
                        const SizedBox(height: 8),
                        ...passes.take(10).map((r) => _carteRdv(r, estAdmin)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _blocVideCalendrier() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_busy_outlined, color: AppColors.muted),
          SizedBox(width: 10),
          Text(
            'Aucun rendez-vous ce jour',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _resume(int nbJour, int nbAvenir) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined,
              size: 18, color: AppColors.rose),
          const SizedBox(width: 8),
          Text(
            '$nbJour aujourd\'hui',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.plum,
            ),
          ),
          const SizedBox(width: 8),
          const Text('•', style: TextStyle(color: AppColors.muted)),
          const SizedBox(width: 8),
          Text(
            '$nbAvenir à venir',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteRdv(RendezVous r, bool estAdmin) {
    final (accent, fond) = switch (r.statut) {
      'terminé' => (AppColors.success, AppColors.successSoft),
      'annulé' => (AppColors.danger, AppColors.dangerSoft),
      _ => (AppColors.warning, AppColors.warningSoft),
    };
    final statut = r.statut.isEmpty
        ? 'prévu'
        : r.statut[0].toUpperCase() + r.statut.substring(1);
    final note = r.note?.trim();

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
          onTap: () => _actions(r),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.roseSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatHeure(r.dateHeure),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.roseDeep,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        formatDate(r.dateHeure),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.roseDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nomClient(r.clientId),
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
                        note == null || note.isEmpty ? 'Sans note' : note,
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
                const SizedBox(width: 6),
                StatusPill(label: statut, color: accent, background: fond),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 20, color: AppColors.muted),
                  onSelected: (valeur) {
                    if (valeur == 'supprimer') {
                      _supprimer(r);
                    } else if (valeur == 'whatsapp') {
                      _rappelWhatsApp(r);
                    } else {
                      _changerStatut(r, valeur);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'whatsapp',
                      child: Text('Rappel WhatsApp'),
                    ),
                    const PopupMenuItem(
                      value: 'terminé',
                      child: Text('Marquer terminé'),
                    ),
                    const PopupMenuItem(
                      value: 'annulé',
                      child: Text('Annuler le RDV'),
                    ),
                    const PopupMenuItem(
                      value: 'prévu',
                      child: Text('Remettre en prévu'),
                    ),
                    if (estAdmin) const PopupMenuDivider(),
                    if (estAdmin)
                      const PopupMenuItem(
                        value: 'supprimer',
                        child: Text(
                          'Supprimer',
                          style: TextStyle(color: AppColors.danger),
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

  void _actions(RendezVous r) {
    final estAdmin = context.read<AuthProvider>().isAdmin;
    showAppSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: _nomClient(r.clientId),
              subtitle:
                  '${formatDateHeure(r.dateHeure)} • ${r.statut.isEmpty ? 'Prévu' : r.statut}',
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.success,
              ),
              title: const Text('Envoyer un rappel WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _rappelWhatsApp(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: AppColors.success),
              title: const Text('Marquer terminé'),
              onTap: () {
                Navigator.pop(ctx);
                _changerStatut(r, 'terminé');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.cancel_outlined, color: AppColors.danger),
              title: const Text('Annuler le rendez-vous'),
              onTap: () {
                Navigator.pop(ctx);
                _changerStatut(r, 'annulé');
              },
            ),
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text('Remettre en prévu'),
              onTap: () {
                Navigator.pop(ctx);
                _changerStatut(r, 'prévu');
              },
            ),
            if (estAdmin)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text(
                  'Supprimer',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _supprimer(r);
                },
              ),
          ],
        ),
      ),
    );
  }
}
