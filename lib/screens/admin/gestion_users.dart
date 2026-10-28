import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/acces_refuse.dart';
import '../../auth/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/hash.dart';
import '../../widgets/empty_state.dart';

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
    final db = await DbHelper.instance.db;
    final res = await db.query('users', orderBy: 'nom');
    if (!mounted) return;
    setState(() {
      _users = res.map(AppUser.fromMap).toList();
      _chargement = false;
    });
  }

  Future<void> _basculerActif(AppUser u) async {
    final auth = context.read<AuthProvider>();
    final current = auth.user;
    if (current?.id == u.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vous ne pouvez pas désactiver votre propre compte.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    final db = await DbHelper.instance.db;
    await db.update('users', {'actif': u.actif ? 0 : 1},
        where: 'id = ?', whereArgs: [u.id]);
    await _charger();
  }

  Future<void> _ajouter() async {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    String role = 'gestionnaire';
    bool obscure = true;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Nouvel utilisateur',
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
                    'Créez un compte pour un membre du personnel.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
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
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nom requis'
                        : null,
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
                        tooltip:
                            obscure ? 'Afficher' : 'Masquer',
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setSheet(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Mot de passe requis';
                      }
                      if (v.length < 4) return 'Minimum 4 caractères';
                      return null;
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
                        icon: Icon(Icons.admin_panel_settings_outlined,
                            size: 16),
                      ),
                    ],
                    selected: {role},
                    onSelectionChanged: (valeurs) =>
                        setSheet(() => role = valeurs.first),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        final db = await DbHelper.instance.db;
                        try {
                          await db.insert(
                            'users',
                            AppUser(
                              nom: nomCtrl.text.trim(),
                              telephone: telCtrl.text.trim(),
                              motDePasseHash: hashPassword(pwdCtrl.text),
                              role: role,
                            ).toMap(),
                          );
                        } catch (_) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Ce numéro de téléphone est déjà utilisé.'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _charger();
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          size: 20),
                      label: const Text('Créer le compte'),
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

  @override
  Widget build(BuildContext context) {
    final estAdmin = context.watch<AuthProvider>().isAdmin;
    if (!estAdmin) {
      return const AccesRefuse(
        message:
            'La gestion des comptes est réservée à l\'administrateur.',
      );
    }

    final actifs = _users.where((u) => u.actif).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
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
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 96),
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
    final accent = u.isAdmin ? AppColors.gold : AppColors.roseDeep;
    final fond = u.isAdmin ? AppColors.goldSoft : AppColors.roseSoft;

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
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: u.actif ? fond : AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: u.actif
                  ? Text(
                      initiales(u.nom),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    )
                  : const Icon(Icons.person_off_outlined,
                      size: 20, color: AppColors.muted),
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
                            color: u.actif
                                ? AppColors.plum
                                : AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: u.isAdmin
                              ? AppColors.goldSoft
                              : AppColors.roseSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          u.isAdmin ? 'Admin' : 'Gestionnaire',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: u.isAdmin
                                ? AppColors.gold
                                : AppColors.roseDeep,
                          ),
                        ),
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
                ],
              ),
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
