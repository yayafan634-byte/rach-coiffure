import 'package:flutter/material.dart';

class Permission {
  final String cle;
  final String label;
  final String description;
  final IconData icon;

  const Permission(this.cle, this.label, this.description, this.icon);
}

const Permission permCaisse = Permission(
  'caisse',
  'Encaisser des ventes',
  'Panier, remise, points fidélité et reçus',
  Icons.point_of_sale_rounded,
);

const Permission permStock = Permission(
  'stock',
  'Gérer le stock',
  'Ajouter et modifier les articles',
  Icons.inventory_2_rounded,
);

const Permission permClients = Permission(
  'clients',
  'Gérer les clients',
  'Créer et mettre à jour les fiches clients',
  Icons.people_alt_rounded,
);

const Permission permRdv = Permission(
  'rdv',
  'Gérer les rendez-vous',
  'Créer, planifier et clôturer les rendez-vous',
  Icons.calendar_month_rounded,
);

const Permission permStats = Permission(
  'stats',
  'Consulter les statistiques',
  'Ventes, marges et meilleures ventes',
  Icons.bar_chart_rounded,
);

const Permission permExports = Permission(
  'exports',
  'Exporter les données',
  'Générer des fichiers CSV et PDF',
  Icons.ios_share_rounded,
);

const Permission permSuppressions = Permission(
  'suppressions',
  'Supprimer des éléments',
  'Articles, rendez-vous et fiches clients',
  Icons.delete_outline_rounded,
);

const List<Permission> kPermissions = [
  permCaisse,
  permStock,
  permClients,
  permRdv,
  permStats,
  permExports,
  permSuppressions,
];

const Set<String> kPermissionsGestionnaireParDefaut = {
  'caisse',
  'stock',
  'clients',
  'rdv',
};

const Set<String> kToutesPermissions = {
  'caisse',
  'stock',
  'clients',
  'rdv',
  'stats',
  'exports',
  'suppressions',
};

Permission? permissionParCle(String cle) {
  for (final p in kPermissions) {
    if (p.cle == cle) return p;
  }
  return null;
}
