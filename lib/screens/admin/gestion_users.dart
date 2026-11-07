import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/permission.dart';
import '../../models/user.dart';
import '../../navigation/app_section.dart';
import '../../theme/app_theme.dart';
import '../../utils/hash.dart';
import '../../utils/id.dart';
import '../../utils/journal.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/status_pill.dart';

class GestionUsersScreen extends StatefulWidget {
  const GestionUsersScreen({super.key});

  @override
  State<GestionUsersScreen> createState() => _GestionUsersScreenState();
}

class _GestionUsersScreenState extends State<GestionUsersScreen> {
  List<AppUser> _users = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final db = await DbHelper.instance.db;
      final res = await db.query('users', orderBy: 'nom');
      if (!mounted) return;
      setState(() {
        _users = res.map(AppUser.fromMap).toList();
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargement = false);
      showAppSnack(
        context,
        'Impossible de charger les utilisateurs.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _basculerActif(AppUser u) async {
    final auth = context.read<AuthProvider>();
    final current = auth.user;
    if (current?.id == u.id) {
      showAppSnack(
        context,
        'Vous ne pouvez pas désactiver votre propre compte.',
        type: AppSnackType.error,
      );
      return;
    }

    if (u.actif) {
      final confirmer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Désactiver ${u.nom} ?'),
          content: const Text(
            'Ce membre du personnel ne pourra plus se connecter au salon.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Désactiver'),
            ),
          ],
        ),
      );
      if (confirmer != true) return;
    }

    try {
      final db = await DbHelper.instance.db;
      await db.update(
        'users',
        {'actif': u.actif ? 0 : 1},
        where: 'id = ?',
        whereArgs: [u.id],
      );
      if (!mounted) return;
      await journaliser(
        context,
        u.actif ? 'Compte désactivé' : 'Compte réactivé',
        details: '${u.nom} • ${u.telephone}',
      );
      await _charger();
      if (mounted) {
        showAppSnack(
          context,
          u.actif ? 'Compte désactivé.' : 'Compte réactivé.',
          type: AppSnackType.success,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Impossible de mettre à jour le compte.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _ajouter() async {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    String role = 'gestionnaire';
    final permissions = {...kPermissionsGestionnaireParDefaut};
    bool obscure = true;
    bool enregistrement = false;
    final formKey = GlobalKey<FormState>();

    await showAppSheet<void>(
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
                    title: 'Nouvel utilisateur',
                    subtitle: 'Créez un compte pour un membre du personnel.',
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
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (identifiant)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Téléphone requis'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pwdCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Afficher' : 'Masquer',
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setSheet(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Mot de passe requis';
                      }
                      return validerMotDePasse(v);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rôle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.plum,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'gestionnaire',
                        label: Text('Gestionnaire'),
                        icon: Icon(Icons.badge_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: 'admin',
                        label: Text('Admin'),
                        icon:
                            Icon(Icons.admin_panel_settings_outlined, size: 16),
                      ),
                    ],
                    selected: {role},
                    onSelectionChanged: (valeurs) =>
                        setSheet(() => role = valeurs.first),
                  ),
                  const SizedBox(height: 18),
                  if (role == 'admin')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.admin_panel_settings_outlined,
                              size: 18, color: AppColors.gold),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Un administrateur dispose automatiquement de toutes les autorisations.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.plum,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const Text(
                      'Autorisations accordées',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.plum,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Choisissez les tâches que ce gestionnaire peut effectuer.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    for (final p in kPermissions)
                      CheckboxListTile(
                        value: permissions.contains(p.cle),
                        onChanged: (v) => setSheet(() {
                          if (v == true) {
                            permissions.add(p.cle);
                          } else {
                            permissions.remove(p.cle);
                          }
                        }),
                        title: Text(
                          p.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.plum,
                          ),
                        ),
                        subtitle: Text(
                          p.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        secondary:
                            Icon(p.icon, size: 19, color: AppColors.rose),
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: enregistrement
                          ? null
                          : () async {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              setSheet(() => enregistrement = true);
                              try {
                                final db = await DbHelper.instance.db;
                                await db.insert(
                                  'users',
                                  AppUser(
                                    id: nouvelId(),
                                    nom: nomCtrl.text.trim(),
                                    telephone: telCtrl.text.trim(),
                                    motDePasseHash: hashPassword(pwdCtrl.text),
                                    role: role,
                                    permissions: role == 'admin'
                                        ? kToutesPermissions
                                        : permissions,
                                  ).toMap(),
                                );
                              } catch (_) {
                                if (!ctx.mounted) return;
                                setSheet(() => enregistrement = false);
                                showAppSnack(
                                  ctx,
                                  'Ce numéro de téléphone est déjà utilisé.',
                                  type: AppSnackType.error,
                                );
                                return;
                              }
                              if (!ctx.mounted) return;
                              await journaliser(
                                ctx,
                                'Compte créé',
                                details: '${nomCtrl.text.trim()} • '
                                    '${role == 'admin' ? 'administrateur' : 'gestionnaire'} • '
                                    '${role == 'admin' ? 'toutes autorisations' : '${permissions.length} autorisation(s)'}',
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _charger();
                              if (mounted) {
                                showAppSnack(
                                  context,
                                  'Compte créé avec succès.',
                                  type: AppSnackType.success,
                                );
                              }
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
                              Icons.person_add_alt_1_rounded,
                              size: 20,
                            ),
                      label: Text(
                        enregistrement ? 'Création...' : 'Créer le compte',
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
  }

  Future<void> _modifierPermissions(AppUser u) async {
    final selection = {...u.permissions};
    var enregistrement = false;

    final enregistre = await showAppSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(
                  title: 'Autorisations',
                  subtitle: '${u.nom} • ${u.telephone}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cochez les tâches que ce gestionnaire peut effectuer. '
                  'Les changements s\'appliquent à sa prochaine connexion.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                for (final p in kPermissions)
                  CheckboxListTile(
                    value: selection.contains(p.cle),
                    onChanged: (v) => setSheet(() {
                      if (v == true) {
                        selection.add(p.cle);
                      } else {
                        selection.remove(p.cle);
                      }
                    }),
                    title: Text(
                      p.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.plum,
                      ),
                    ),
                    subtitle: Text(
                      p.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    secondary: Icon(p.icon, size: 19, color: AppColors.rose),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: enregistrement
                        ? null
                        : () async {
                            setSheet(() => enregistrement = true);
                            try {
                              final db = await DbHelper.instance.db;
                              await db.update(
                                'users',
                                {
                                  'permissions': selection.join(','),
                                },
                                where: 'id = ?',
                                whereArgs: [u.id],
                              );
                            } catch (_) {
                              if (!ctx.mounted) return;
                              setSheet(() => enregistrement = false);
                              showAppSnack(
                                ctx,
                                'Impossible de mettre à jour les autorisations.',
                                type: AppSnackType.error,
                              );
                              return;
                            }
                            if (!ctx.mounted) return;
                            await journaliser(
                              ctx,
                              'Autorisations modifiées',
                              details: '${u.nom} • '
                                  '${selection.length}/${kPermissions.length} autorisation(s)',
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
                        : const Icon(Icons.verified_user_outlined, size: 20),
                    label: Text(
                      enregistrement
                          ? 'Enregistrement...'
                          : 'Enregistrer les autorisations',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (enregistre == true && mounted) {
      await _charger();
      if (!mounted) return;
      showAppSnack(
        context,
        'Autorisations mises à jour.',
        type: AppSnackType.success,
      );
    }
  }

  Future<void> _reinitialiserMotDePasse(AppUser u) async {
    final pwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;
    bool enregistrement = false;

    final valide = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Mot de passe de ${u.nom}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Le compte devra choisir un nouveau mot de passe à sa '
                  'prochaine connexion.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: pwdCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      tooltip: obscure ? 'Afficher' : 'Masquer',
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialog(() => obscure = !obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Mot de passe requis'
                      : validerMotDePasse(v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  enregistrement ? null : () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: enregistrement
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialog(() => enregistrement = true);
                      final erreur = await context
                          .read<AuthProvider>()
                          .reinitialiserMotDePasse(u.id!, pwdCtrl.text);
                      if (!ctx.mounted) return;
                      if (erreur != null) {
                        setDialog(() => enregistrement = false);
                        showAppSnack(ctx, erreur, type: AppSnackType.error);
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
              child:
                  Text(enregistrement ? 'Enregistrement...' : 'Réinitialiser'),
            ),
          ],
        ),
      ),
    );

    pwdCtrl.dispose();
    if (valide == true && mounted) {
      showAppSnack(
        context,
        'Mot de passe réinitialisé.',
        type: AppSnackType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estAdmin = context.watch<AuthProvider>().isAdmin;
    if (!estAdmin) {
      return const AccesRefuse(
        message: 'La gestion des comptes est réservée à l\'administrateur.',
      );
    }

    final actifs = _users.where((u) => u.actif).length;

    return AppShell(
      section: AppSection.utilisateurs,
      title: 'Utilisateurs',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Utilisateur'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? EmptyState(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Aucun utilisateur',
                  message: 'Créez un compte pour le personnel du salon.',
                  actionLabel: 'Créer un compte',
                  onAction: _ajouter,
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined,
                              size: 16, color: AppColors.muted),
                          const SizedBox(width: 6),
                          Text(
                            '$actifs compte(s) actif(s) sur ${_users.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _charger,
                        color: AppColors.rose,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _users.length,
                          itemBuilder: (ctx, i) => _carteUser(_users[i]),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _carteUser(AppUser u) {
    final monId = context.read<AuthProvider>().user?.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            InitialsAvatar(
              name: u.nom,
              size: 42,
              muted: !u.actif,
              fallbackIcon: Icons.person_off_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          u.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: u.actif ? AppColors.plum : AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusPill(
                        label: u.isAdmin ? 'Admin' : 'Gestionnaire',
                        color: u.isAdmin ? AppColors.gold : AppColors.roseDeep,
                        background:
                            u.isAdmin ? AppColors.goldSoft : AppColors.roseSoft,
                        icon: u.isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.badge_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    u.telephone,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    u.isAdmin
                        ? 'Toutes les autorisations'
                        : '${u.permissions.length}/${kPermissions.length} autorisation(s)',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            if (!u.isAdmin)
              IconButton(
                tooltip: 'Modifier les autorisations',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.tune_rounded, size: 19),
                color: AppColors.muted,
                onPressed: () => _modifierPermissions(u),
              ),
            if (u.id != monId)
              IconButton(
                tooltip: 'Réinitialiser le mot de passe',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.lock_reset_rounded, size: 19),
                color: AppColors.muted,
                onPressed: () => _reinitialiserMotDePasse(u),
              ),
            Switch(
              value: u.actif,
              onChanged: (_) => _basculerActif(u),
            ),
          ],
        ),
      ),
    );
  }
}
