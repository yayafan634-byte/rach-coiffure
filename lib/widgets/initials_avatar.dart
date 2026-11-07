import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool muted;
  final IconData fallbackIcon;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 42,
    this.muted = false,
    this.fallbackIcon = Icons.person_outline_rounded,
  });

  static const _palettes = <(Color, Color)>[
    (AppColors.roseDeep, AppColors.roseSoft),
    (AppColors.gold, AppColors.goldSoft),
    (AppColors.success, AppColors.successSoft),
    (Color(0xFF5F7A9B), Color(0xFFE7EEF6)),
    (Color(0xFF6A4C93), Color(0xFFEFE8F7)),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final index =
        trimmed.isEmpty ? 0 : trimmed.codeUnitAt(0) % _palettes.length;
    final (accent, fond) = _palettes[index];

    return Semantics(
      image: true,
      label: trimmed.isEmpty ? 'Avatar' : 'Avatar de $trimmed',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: muted ? AppColors.slate100 : fond,
          shape: BoxShape.circle,
        ),
        child: trimmed.isEmpty
            ? Icon(
                fallbackIcon,
                size: size * 0.44,
                color: AppColors.muted,
              )
            : Text(
                initiales(trimmed),
                style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w700,
                  color: muted ? AppColors.muted : accent,
                ),
              ),
      ),
    );
  }
}
