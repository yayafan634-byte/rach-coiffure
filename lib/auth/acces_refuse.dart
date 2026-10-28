import 'package:flutter/material.dart';
import '../widgets/empty_state.dart';

class AccesRefuse extends StatelessWidget {
  final String message;

  const AccesRefuse({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accès refusé')),
      body: EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Accès réservé',
        message: message,
        actionLabel: 'Retour',
        onAction: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
