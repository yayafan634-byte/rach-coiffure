import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../theme/app_theme.dart';
import '../../utils/journal.dart';
import '../../widgets/app_sheet.dart';
import '../../utils/id.dart';
import '../../widgets/app_snack.dart';

Future<bool> showClientFormSheet(
  BuildContext context, {
  Client? client,
}) async {
  final resultat = await showAppSheet<bool>(
    context,
    builder: (ctx) => _ClientForm(client: client),
  );
  return resultat ?? false;
}

class _ClientForm extends StatefulWidget {
  final Client? client;

  const _ClientForm({this.client});

  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _telephone;
  late final TextEditingController _adresse;
  DateTime? _dateNaissance;
  bool _enregistrement = false;

  bool get _modification => widget.client != null;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.client?.nom ?? '');
    _telephone = TextEditingController(text: widget.client?.telephone ?? '');
    _adresse = TextEditingController(text: widget.client?.adresse ?? '');
    _dateNaissance = widget.client?.dateNaissance;
  }

  Future<void> _choisirDateNaissance() async {
    final maintenant = DateTime.now();
    final choix = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(maintenant.year - 25),
      firstDate: DateTime(1900),
      lastDate: maintenant,
      helpText: 'Date de naissance',
    );
    if (choix != null && mounted) {
      setState(() => _dateNaissance = choix);
    }
  }

  String _formatDate(DateTime date) {
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _adresse.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enregistrement = true);

    final db = await DbHelper.instance.db;
    final telephone = _telephone.text.trim();
    final doublon = await db.query(
      'clients',
      columns: ['id'],
      where: _modification ? 'telephone = ? AND id <> ?' : 'telephone = ?',
      whereArgs: _modification ? [telephone, widget.client!.id] : [telephone],
      limit: 1,
    );

    if (!mounted) return;
    if (doublon.isNotEmpty) {
      setState(() => _enregistrement = false);
      showAppSnack(
        context,
        'Ce numéro de téléphone est déjà utilisé.',
        type: AppSnackType.error,
      );
      return;
    }

    final client = Client(
      id: widget.client?.id,
      nom: _nom.text.trim(),
      telephone: telephone,
      adresse: _adresse.text.trim().isEmpty ? null : _adresse.text.trim(),
      pointsFidelite: widget.client?.pointsFidelite ?? 0,
      dateCreation: widget.client?.dateCreation,
      dateNaissance: _dateNaissance,
    );

    try {
      if (_modification) {
        await db.update(
          'clients',
          client.toMap(),
          where: 'id = ?',
          whereArgs: [client.id],
        );
      } else {
        final map = client.toMap();
        map['id'] = nouvelId();
        await db.insert('clients', map);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      showAppSnack(
        context,
        'Impossible d\'enregistrer le client.',
        type: AppSnackType.error,
      );
      return;
    }

    if (!mounted) return;
    await journaliser(
      context,
      _modification ? 'Client modifié' : 'Client ajouté',
      details: '${client.nom} • ${client.telephone}',
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: _modification ? 'Modifier le client' : 'Nouveau client',
            subtitle: _modification
                ? 'Mettez à jour les informations du client.'
                : 'Ajoutez un client au répertoire du salon.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telephone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) {
              final valeur = v?.trim() ?? '';
              if (valeur.isEmpty) return 'Téléphone requis';
              if (valeur.replaceAll(RegExp(r'\D'), '').length < 6) {
                return 'Numéro de téléphone invalide';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adresse,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Adresse (optionnel)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _choisirDateNaissance,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date de naissance (optionnel)',
                prefixIcon: const Icon(Icons.cake_outlined),
                suffixIcon: _dateNaissance == null
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => setState(() => _dateNaissance = null),
                      ),
              ),
              child: Text(
                _dateNaissance == null
                    ? 'Non renseignée'
                    : _formatDate(_dateNaissance!),
                style: TextStyle(
                  fontSize: 14,
                  color: _dateNaissance == null
                      ? AppColors.muted
                      : AppColors.slate900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _modification
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                      size: 20,
                    ),
              label: Text(
                _enregistrement
                    ? 'Enregistrement...'
                    : (_modification
                        ? 'Enregistrer les modifications'
                        : 'Ajouter le client'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
