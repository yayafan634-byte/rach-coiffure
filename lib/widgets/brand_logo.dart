import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool shadow;

  const BrandLogo({super.key, this.size = 92, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.rose.withValues(alpha: 0.24),
                  blurRadius: size * 0.3,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/app_logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.roseSoft,
            alignment: Alignment.center,
            child: Icon(
              Icons.content_cut_rounded,
              size: size * 0.42,
              color: AppColors.roseDeep,
            ),
          ),
        ),
      ),
    );
  }
}
