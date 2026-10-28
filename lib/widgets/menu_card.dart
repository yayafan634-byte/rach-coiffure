import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accent;
  final Color background;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.accent = AppColors.rose,
    this.background = AppColors.roseSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppColors.line),
      ),
      elevation: 0,
      shadowColor: const Color(0x103E2B33),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        splashColor: AppColors.roseSoft.withValues(alpha: 0.4),
        highlightColor: AppColors.roseSoft.withValues(alpha: 0.25),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: AppColors.plum,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppTheme.space4),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
