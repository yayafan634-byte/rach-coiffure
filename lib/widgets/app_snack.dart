import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppSnackType { success, error, info }

void showAppSnack(
  BuildContext context,
  String message, {
  AppSnackType type = AppSnackType.info,
  SnackBarAction? action,
}) {
  final (background, icon) = switch (type) {
    AppSnackType.success => (AppColors.success, Icons.check_circle_rounded),
    AppSnackType.error => (AppColors.danger, Icons.error_outline_rounded),
    AppSnackType.info => (AppColors.plum, Icons.info_outline_rounded),
  };

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        action: action,
        content: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
