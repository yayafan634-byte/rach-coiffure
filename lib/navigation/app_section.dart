import 'package:flutter/material.dart';

enum AppSection {
  dashboard(
    '/dashboard',
    'Tableau de bord',
    'Vue d\'ensemble du salon',
    Icons.space_dashboard_rounded,
    false,
  ),
  stock(
    '/stock',
    'Stock',
    'Perruques & quantités',
    Icons.inventory_2_rounded,
    false,
    permission: 'stock',
  ),
  clients(
    '/clients',
    'Clients',
    'Répertoire & fidélité',
    Icons.people_alt_rounded,
    false,
    permission: 'clients',
  ),
  caisse(
    '/caisse',
    'Caisse',
    'Encaisser une vente',
    Icons.point_of_sale_rounded,
    false,
    permission: 'caisse',
  ),
  rdv(
    '/rdv',
    'Rendez-vous',
    'Agenda du salon',
    Icons.calendar_month_rounded,
    false,
    permission: 'rdv',
  ),
  stats(
    '/stats',
    'Statistiques',
    'Ventes, marges & top',
    Icons.bar_chart_rounded,
    false,
    permission: 'stats',
  ),
  utilisateurs(
    '/utilisateurs',
    'Utilisateurs',
    'Comptes & permissions',
    Icons.manage_accounts_rounded,
    true,
  ),
  historique(
    '/historique',
    'Historique',
    'Journal des actions du salon',
    Icons.history_rounded,
    true,
  );

  const AppSection(
    this.route,
    this.label,
    this.description,
    this.icon,
    this.adminSeulement, {
    this.permission,
  });

  final String route;
  final String label;
  final String description;
  final IconData icon;
  final bool adminSeulement;
  final String? permission;

  bool accessiblePour(bool isAdmin, bool Function(String cle) peut) {
    if (adminSeulement && !isAdmin) return false;
    final cle = permission;
    return cle == null || peut(cle);
  }
}
