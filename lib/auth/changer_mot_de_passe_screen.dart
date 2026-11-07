import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/admin/admin_dashboard.dart';
import '../screens/gestionnaire/gestionnaire_dashboard.dart';
import '../theme/app_theme.dart';
import 'auth_provider.dart';
import 'login_screen.dart';

class ChangerMotDePasseScreen extends StatefulWidget {
  final bool obligatoire;

  const ChangerMotDePasseScreen({super.key, this.obligatoire = false});

  @override
  State<ChangerMotDePasseScreen> createState() =>
      _ChangerMotDePasseScreenState();
}

class _ChangerMotDePasseScreenState extends State<ChangerMotDePasseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actuelCtrl = TextEditingController();
  final _nouveauCtrl = TextEditingController();
  final _confirmationCtrl = TextEditingController();
  bool _obscure = true;
  bool _enregistrement = false;
  String? _erreur;

  @override
  void dispose() {
    _actuelCtrl.dispose();
    _nouveauCtrl.dispose();
    _confirmationCtrl.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });

    final auth = context.read<AuthProvider>();
    final erreur = await auth.changerMotDePasse(
      actuel: _actuelCtrl.text,
      nouveau: _nouveauCtrl.text,
      verifierActuel: !widget.obligatoire,
    );
    if (!mounted) return;

    if (erreur != null) {
      setState(() {
        _enregistrement = false;
        _erreur = erreur;
      });
      return;
    }

    if (widget.obligatoire) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => auth.isAdmin
              ? const AdminDashboard()
              : const GestionnaireDashboard(),
        ),
        (r) => false,
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deconnecter() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.obligatoire,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.obligatoire,
          title: const Text('Mot de passe'),
          actions: [
            if (widget.obligatoire)
              TextButton(
                onPressed: _deconnecter,
                child: const Text('Se déconnecter'),
              ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.obligatoire) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.amberSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined,
                                  size: 20, color: AppColors.warning),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Le mot de passe par défaut doit être remplacé '
                                  'avant de continuer.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.slate700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        widget.obligatoire
                            ? 'Nouveau mot de passe'
                            : 'Changer mon mot de passe',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '8 caractères minimum, avec au moins une lettre et un chiffre.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!widget.obligatoire) ...[
                        TextFormField(
                          controller: _actuelCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe actuel',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Afficher' : 'Masquer',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Mot de passe actuel requis'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _nouveauCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          prefixIcon: Icon(Icons.lock_reset_rounded),
                        ),
                        validator: (v) => validerMotDePasse(v ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmationCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _enregistrer(),
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le mot de passe',
                          prefixIcon: Icon(Icons.check_circle_outline_rounded),
                        ),
                        validator: (v) => v != _nouveauCtrl.text
                            ? 'Les deux mots de passe ne correspondent pas'
                            : null,
                      ),
                      if (_erreur != null) ...[
                        const SizedBox(height: 14),
                        Container(
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
                              const Icon(Icons.error_outline,
                                  size: 18, color: AppColors.danger),
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
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _enregistrement ? null : _enregistrer,
                          child: _enregistrement
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
