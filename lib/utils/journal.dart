import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../services/activite_service.dart';

Future<void> journaliser(
  BuildContext context,
  String action, {
  String? details,
}) async {
  final user = context.read<AuthProvider>().user;
  await ActiviteService.instance.log(
    action: action,
    details: details,
    utilisateur: user?.nom,
    userId: user?.id,
  );
}
