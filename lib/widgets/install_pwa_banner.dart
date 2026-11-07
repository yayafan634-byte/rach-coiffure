import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/install_pwa.dart';

const String kUrlApplication =
    'https://yayafan634-byte.github.io/rach-coiffure/';

class InstallPwaBanner extends StatefulWidget {
  const InstallPwaBanner({super.key});

  @override
  State<InstallPwaBanner> createState() => _InstallPwaBannerState();
}

class _InstallPwaBannerState extends State<InstallPwaBanner> {
  bool _ferme = false;

  void _ouvrirAide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AideInstallation(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ferme || !pwaInvitePossible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.roseSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _ouvrirAide,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.ios_share,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Installez l'application",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Touchez ici pour voir les étapes (Partager puis '
                        '« Sur l\'écran d\'accueil »).',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.muted,
                  onPressed: () => setState(() => _ferme = true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AideInstallation extends StatelessWidget {
  const _AideInstallation();

  Future<void> _copier(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kUrlApplication));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié. Collez-le dans Safari.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.rose,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.ios_share,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Installer sur iPhone",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.plum,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Aucun bouton « Installer » sur Safari : '
                          'l\'ajout se fait depuis le menu Partager.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _Etape(
                numero: '1',
                titre: 'Ouvrez le site dans Safari',
                texte: 'Si le lien vient de WhatsApp, Facebook ou Instagram, '
                    'touchez ⋯ puis « Ouvrir dans Safari ».',
              ),
              const _Etape(
                numero: '2',
                titre: 'Touchez l\'icône Partager',
                texte:
                    'C\'est le carré avec une flèche vers le haut, en bas de '
                    'l\'écran (ou en haut sur iPad).',
              ),
              const _Etape(
                numero: '3',
                titre: 'Choisissez « Sur l\'écran d\'accueil »',
                texte: 'Faites défiler le menu si l\'option n\'apparaît pas.',
              ),
              const _Etape(
                numero: '4',
                titre: 'Touchez « Ajouter »',
                texte: 'L\'icône Rach Coiffure apparaît alors sur votre '
                    'écran d\'accueil, comme une vraie application.',
                dernier: true,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Une fois installée, ouvrez l\'app depuis son icône : '
                        'elle s\'affiche en plein écran, sans barre Safari.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copier(context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copier le lien'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('J\'ai compris'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  final String numero;
  final String titre;
  final String texte;
  final bool dernier;

  const _Etape({
    required this.numero,
    required this.titre,
    required this.texte,
    this.dernier = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: dernier ? 8 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.roseSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.rose.withValues(alpha: 0.25),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              numero,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.roseDeep,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.plum,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texte,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
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
