import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'changer_mot_de_passe_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/gestionnaire/gestionnaire_dashboard.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/install_pwa_banner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _telCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  String? _erreur;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _telCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _effacerErreur() {
    if (_erreur != null) setState(() => _erreur = null);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _erreur = null;
    });

    final auth = context.read<AuthProvider>();
    final err = await auth.login(_telCtrl.text.trim(), _pwdCtrl.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _erreur = err);
    } else if (auth.doitChangerMotDePasse) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => const ChangerMotDePasseScreen(obligatoire: true),
      ));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => auth.isAdmin
            ? const AdminDashboard()
            : const GestionnaireDashboard(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.sizeOf(context).width >= 900;

    if (large) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            Expanded(
              flex: 11,
              child: _panneauMarque(),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.line,
            ),
            Expanded(
              flex: 9,
              child: ColoredBox(
                color: AppColors.background,
                child: _zoneFormulaire(avecMarque: false),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8E9EB),
              AppColors.cream,
              Color(0xFFF7EFE2),
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: _bulle(220, AppColors.rose.withValues(alpha: 0.10)),
            ),
            Positioned(
              bottom: -100,
              left: -70,
              child: _bulle(260, AppColors.gold.withValues(alpha: 0.10)),
            ),
            _zoneFormulaire(avecMarque: true),
          ],
        ),
      ),
    );
  }

  Widget _panneauMarque() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFDF2F4),
            Color(0xFFFFFBF5),
            Color(0xFFF8E9EB),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -50,
            child: _bulle(220, AppColors.rose.withValues(alpha: 0.09)),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _bulle(300, AppColors.gold.withValues(alpha: 0.10)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLogo(size: 96),
                      const SizedBox(height: 26),
                      const Text(
                        'Rach Coiffure',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.9,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Gérez votre salon avec élégance : stock, clients, '
                        'rendez-vous et caisse réunis dans une seule '
                        'application.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const _Avantage(
                        icon: Icons.inventory_2_rounded,
                        texte:
                            'Suivi du stock et alertes de réapprovisionnement',
                        couleur: AppColors.rose,
                      ),
                      const _Avantage(
                        icon: Icons.people_alt_rounded,
                        texte: 'Clients, fidélité et historique des visites',
                        couleur: AppColors.blue,
                      ),
                      const _Avantage(
                        icon: Icons.point_of_sale_rounded,
                        texte: 'Caisse, reçus et statistiques en temps réel',
                        couleur: AppColors.emerald,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: AppColors.muted,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Accès réservé au personnel du salon',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneFormulaire({required bool avecMarque}) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (avecMarque) ...[
                  const BrandLogo(size: 92),
                  const SizedBox(height: 20),
                  const Text(
                    'Rach Coiffure',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.plum,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Gérez votre salon avec élégance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                ] else ...[
                  const Text(
                    'ESPACE PERSONNEL',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.roseDeep,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const InstallPwaBanner(),
                _carteFormulaire(),
                const SizedBox(height: 22),
                const Text(
                  'Accès réservé au personnel du salon',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _carteFormulaire() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F3E2B33),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Connexion',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.plum,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Entrez vos identifiants pour continuer.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: (_) => _effacerErreur(),
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pwdCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => _effacerErreur(),
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Champ requis' : null,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _erreur == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _erreur!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Se connecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulle(double taille, Color couleur) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
    );
  }
}

class _Avantage extends StatelessWidget {
  final IconData icon;
  final String texte;
  final Color couleur;

  const _Avantage({
    required this.icon,
    required this.texte,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: couleur),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
