import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/rendez_vous.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
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
    final db = await DbHelper.instance.db;
    final rdvRes = await db.query('rendezVous', orderBy: 'dateHeure');
    final clientRes = await db.query('clients', orderBy: 'nom');
    if (!mounted) return;
    setState(() {
      _rdvs = rdvRes.map(RendezVous.fromMap).toList();
      _clients = clientRes.map(Client.fromMap).toList();
      _chargement = false;
    });
  }

  Future<void> _ajouter() async {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Ajoutez d\'abord un client.'),
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
      ));
      return;
    }

    int clientId = _clients.first.id!;
    DateTime date = DateTime.now();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
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
                        'Nouveau rendez-vous',
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
                  'Planifiez un rendez-vous pour un client.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
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
                StatefulBuilder(
                  builder: (ctx, setSheet) => Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: const Icon(Icons.calendar_month_outlined,
                          color: AppColors.rose),
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
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (d == null || !ctx.mounted) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(date),
                        );
                        if (t == null) return;
                        setSheet(() {
                          date = DateTime(
                              d.year, d.month, d.day, t.hour, t.minute);
                        });
                      },
                    ),
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
                    onPressed: () async {
                      final db = await DbHelper.instance.db;
                      await db.insert(
                        'rendezVous',
                        RendezVous(
                          clientId: clientId,
                          dateHeure: date,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        ).toMap(),
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _charger();
                    },
                    icon: const Icon(Icons.event_available_rounded, size: 20),
                    label: const Text('Enregistrer le rendez-vous'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changerStatut(RendezVous r, String statut) async {
    final db = await DbHelper.instance.db;
    await db.update(
      'rendezVous',
      {'statut': statut},
      where: 'id = ?',
      whereArgs: [r.id],
    );
    await _charger();
  }

  Future<void> _supprimer(RendezVous r) async {
    if (!context.read<AuthProvider>().isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Suppression réservée à l\'administrateur.'),
        backgroundColor: AppColors.danger,
      ));
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

    final db = await DbHelper.instance.db;
    await db.delete('rendezVous', where: 'id = ?', whereArgs: [r.id]);
    await _charger();
  }

  String _nomClient(int id) {
    final c = _clients.where((c) => c.id == id).toList();
    return c.isEmpty ? 'Client #$id' : c.first.nom;
  }

  List<RendezVous> _rdvDuJour(DateTime day) {
    final debut = DateTime(day.year, day.month, day.day);
    final fin = debut.add(const Duration(days: 1));
    return _rdvs
        .where((r) =>
            !r.dateHeure.isBefore(debut) && r.dateHeure.isBefore(fin))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day);
    final debutDemain = debutJour.add(const Duration(days: 1));

    final aujourdHui = _rdvs
        .where((r) =>
            !r.dateHeure.isBefore(debutJour) &&
            r.dateHeure.isBefore(debutDemain))
        .toList();
    final aVenir = _rdvs
        .where((r) => !r.dateHeure.isBefore(debutDemain))
        .toList();
    final passes = _rdvs
        .where((r) => r.dateHeure.isBefore(debutJour))
        .toList()
        .reversed
        .toList();

    final rdvSelectionnes = _rdvDuJour(_selectedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('Rendez-vous')),
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
                        title:
                            'RDV du ${formatDate(_selectedDay)}',
                      ),
                      const SizedBox(height: 8),
                      if (rdvSelectionnes.isEmpty)
                        _blocVideCalendrier()
                      else
                        ...rdvSelectionnes.map(_carteRdv),
                      if (aujourdHui.isNotEmpty && !isSameDay(_selectedDay, now)) ...[
                        const SizedBox(height: 18),
                        const SectionHeader(title: "Aujourd'hui"),
                        const SizedBox(height: 8),
                        ...aujourdHui.map(_carteRdv),
                      ],
                      if (aVenir.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const SectionHeader(title: 'À venir'),
                        const SizedBox(height: 8),
                        ...aVenir.take(5).map(_carteRdv),
                      ],
                      if (passes.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const SectionHeader(title: 'Passés'),
                        const SizedBox(height: 8),
                        ...passes.take(10).map(_carteRdv),
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

  Widget _carteRdv(RendezVous r) {
    final estAdmin = context.watch<AuthProvider>().isAdmin;
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: fond,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statut,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 20, color: AppColors.muted),
                  onSelected: (valeur) {
                    if (valeur == 'supprimer') {
                      _supprimer(r);
                    } else {
                      _changerStatut(r, valeur);
                    }
                  },
                  itemBuilder: (_) => [
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
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.danger),
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
