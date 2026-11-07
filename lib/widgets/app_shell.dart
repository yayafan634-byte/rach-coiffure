import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../auth/changer_mot_de_passe_screen.dart';
import '../auth/login_screen.dart';
import '../navigation/app_section.dart';
import '../theme/app_theme.dart';
import 'brand_logo.dart';
import 'initials_avatar.dart';

const double kBreakpointDesktop = 1024;
const double kLargeurSidebar = 266;
const double kLargeurContenu = 1180;

class AppShell extends StatelessWidget {
  final AppSection section;
  final String title;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final double maxWidthContenu;

  const AppShell({
    super.key,
    required this.section,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.maxWidthContenu = kLargeurContenu,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final large = MediaQuery.sizeOf(context).width >= kBreakpointDesktop;
    final barre = _barreApp(context, auth, large);

    if (large) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: kLargeurSidebar,
              child: _BarreLaterale(
                section: section,
                auth: auth,
                dansDrawer: false,
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.line,
            ),
            Expanded(
              child: Scaffold(
                backgroundColor: AppColors.background,
                appBar: barre,
                body: _corps(large),
                floatingActionButton: floatingActionButton,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: barre,
      drawer: Drawer(
        width: 300,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: _BarreLaterale(
          section: section,
          auth: auth,
          dansDrawer: true,
        ),
      ),
      body: _corps(large),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _corps(bool large) {
    if (!large) return body;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidthContenu),
        child: body,
      ),
    );
  }

  AppBar _barreApp(BuildContext context, AuthProvider auth, bool large) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: large ? AppTheme.space24 : null,
      leading: large
          ? null
          : Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      title: Text(title),
      actions: [
        ...actions,
        const SizedBox(width: 4),
        _MenuCompte(auth: auth),
        const SizedBox(width: 10),
      ],
    );
  }
}

class _BarreLaterale extends StatelessWidget {
  final AppSection section;
  final AuthProvider auth;
  final bool dansDrawer;

  const _BarreLaterale({
    required this.section,
    required this.auth,
    required this.dansDrawer,
  });

  String get _nom {
    final brut = auth.user?.nom.trim() ?? '';
    return brut.isEmpty ? 'Utilisateur' : brut;
  }

  String get _role => auth.isAdmin ? 'Administrateur' : 'Gestionnaire';

  void _aller(BuildContext context, AppSection cible) {
    if (dansDrawer) {
      Scaffold.of(context).closeDrawer();
    }
    if (cible == section) return;
    if (cible == AppSection.dashboard) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      cible.route,
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = AppSection.values
        .where((s) => s.accessiblePour(auth.isAdmin, auth.peut))
        .toList();

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            const _EnteteMarque(),
            const SizedBox(height: AppTheme.space8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                children: [
                  const _Etiquette('NAVIGATION'),
                  const SizedBox(height: AppTheme.space4),
                  for (final s in sections)
                    _LienSection(
                      section: s,
                      actif: s == section,
                      onTap: () => _aller(context, s),
                    ),
                ],
              ),
            ),
            _PiedCompte(
              nom: _nom,
              role: _role,
              onDeconnexion: () => _deconnecter(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deconnecter(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Voulez-vous fermer la session en cours ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmer != true || !context.mounted) return;
    await auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }
}

class _EnteteMarque extends StatelessWidget {
  const _EnteteMarque();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF2F4), Color(0xFFFFFBF5)],
        ),
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: const Row(
        children: [
          BrandLogo(size: 44),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rach Coiffure',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.plum,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Gestion du salon',
                  style: TextStyle(
                    fontSize: 11.5,
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
}

class _Etiquette extends StatelessWidget {
  final String texte;

  const _Etiquette(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        texte,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.slate400,
        ),
      ),
    );
  }
}

class _LienSection extends StatelessWidget {
  final AppSection section;
  final bool actif;
  final VoidCallback onTap;

  const _LienSection({
    required this.section,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: actif ? AppColors.roseSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          splashColor: AppColors.roseSoft.withValues(alpha: 0.6),
          highlightColor: AppColors.roseSoft.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 20,
                  color: actif ? AppColors.roseDeep : AppColors.slate500,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: actif ? FontWeight.w700 : FontWeight.w600,
                      color: actif ? AppColors.roseDeep : AppColors.slate700,
                    ),
                  ),
                ),
                if (actif)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.rose,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PiedCompte extends StatelessWidget {
  final String nom;
  final String role;
  final VoidCallback onDeconnexion;

  const _PiedCompte({
    required this.nom,
    required this.role,
    required this.onDeconnexion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          InitialsAvatar(name: nom, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.plum,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  role,
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
          IconButton(
            tooltip: 'Se déconnecter',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.logout_rounded, size: 18),
            color: AppColors.muted,
            onPressed: onDeconnexion,
          ),
        ],
      ),
    );
  }
}

class _MenuCompte extends StatelessWidget {
  final AuthProvider auth;

  const _MenuCompte({required this.auth});

  @override
  Widget build(BuildContext context) {
    final nomBrut = auth.user?.nom.trim() ?? '';
    final nom = nomBrut.isEmpty ? 'Utilisateur' : nomBrut;
    final role = auth.isAdmin ? 'Administrateur' : 'Gestionnaire';

    return PopupMenuButton<String>(
      tooltip: 'Mon compte',
      offset: const Offset(0, 46),
      onSelected: (valeur) {
        if (valeur == 'deconnexion') {
          _deconnecter(context);
        } else if (valeur == 'changer_mdp') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ChangerMotDePasseScreen(),
            ),
          );
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              InitialsAvatar(name: nom, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nom,
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
                      role,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'changer_mdp',
          child: Row(
            children: [
              Icon(Icons.lock_reset_rounded,
                  size: 18, color: AppColors.slate700),
              SizedBox(width: 10),
              Text(
                'Changer mon mot de passe',
                style: TextStyle(fontSize: 13.5, color: AppColors.slate700),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'deconnexion',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
              SizedBox(width: 10),
              Text(
                'Se déconnecter',
                style: TextStyle(fontSize: 13.5, color: AppColors.danger),
              ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialsAvatar(name: nom, size: 36),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deconnecter(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Voulez-vous fermer la session en cours ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmer != true || !context.mounted) return;
    await auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }
}
