# Journal du projet — Salon Perruques BF

Fichier tenu à jour par l'assistant à chaque session (continuité entre les conversations).

## Session 1 — 18/10/2026

**État constaté :**
- App Flutter (sqflite, provider) : auth + users, perruques (stock), clients, prestations, RDV, ventes.
- DB version 1, tables créées dans `lib/database/db_helper.dart`.
- Écran stock : ajout + suppression (long press), alerte visuelle stock bas (≤3), pas de modification.

**Améliorations proposées (à prioriser avec l'utilisateur) :**
1. Modifier un article en stock (aujourd'hui seulement ajouter/supprimer).
2. Recherche / filtres dans le stock (type, couleur, stock bas).
3. Décrémenter automatiquement le stock lors d'une vente (vérifier `caisse_screen.dart`).
4. Historique des mouvements de stock (entrées/sorties) + page statistiques (CA, best-sellers, alertes stock).
5. Validation des formulaires (champs vides, prix négatifs).
6. Version DB + `onUpgrade` pour les futures modifications de schéma.
7. Sauvegarde/export des données (CSV ou JSON).
8. Photos des perruques (champ `photoPath` existe, pas de sélecteur).

**Décisions :** aucune pour l'instant.

## Session 2 — 20/10/2026 (état constaté, aucun changement fait ce jour)

**Réalisé depuis la session 1 :**
- DB version 2 + `_onUpgrade` (`lib/database/db_helper.dart`) : table `mouvements_stock`, colonne `quantite` sur `ventes`.
- Service stock (`lib/services/stock_service.dart`) : entrées/sorties en transaction, décrément automatique du stock à la vente.
- Stock : modification d'un article (formulaire partagé ajout/modif).
- Page `mouvements_screen.dart` : historique entrées/sorties.
- Page `stats_screen.dart` : CA, best-sellers, alertes stock (1 warning : champ `_valeurStockVente` inutilisé).
- Export CSV (`lib/utils/export_csv.dart`).
- Dashboards admin/gestionnaire et clients mis à jour.

**Reste à faire :**
1. Recherche / filtres dans le stock (type, couleur, stock bas).
2. Validation des formulaires (champs vides, prix négatifs).
3. Photos des perruques (champ `photoPath` existe, pas de sélecteur).
4. Corriger les 3 issues `flutter analyze` (1 warning + 2 infos).
5. Tester sur device/emulateur (pas de build récent depuis les changements).

## Session 3 — 20/10/2026

**Réalisé :**
- `flutter analyze` : 0 issue (fix BuildContext async gap caisse, champ inutilisé stats, const export_csv).
- Validation gestion utilisateurs (Form + validators, mdp ≥ 4 car.) — stock/clients/caisse avaient déjà leurs validations.
- Photos perruques : dépendance `image_picker` ajoutée, sélecteur galerie dans le dialog stock (copie dans Documents/photos), vignette dans la liste.
- `flutter test` : 1 test OK. `flutter build apk --release` : **succès** → `build\app\outputs\flutter-apk\app-release.apk` (50.1 MB).
- Note : erreur symlink Windows (`file_selector_windows`) lors du pub get (pas de droits symlink) — bloque éventuellement le build desktop Windows, pas l'APK Android.

**Statut :** app prête à être installée sur téléphone (APK release). À tester en conditions réelles.

## Session 4 — 23/10/2026

**Objectif rappelé :** l'app devra aussi être accessible sur iPhone.

**Contrainte :** un build iOS exige un Mac avec Xcode (impossible depuis Windows). Options : Mac emprunté, CI macOS (Codemagic / GitHub Actions), ou Mac cloud. Test sur iPhone réel : compte Apple Developer (99 $/an) pour TestFlight/App Store ; sinon installation locale via Xcode (certificat 7 jours).

**Réalisé :**
- `ios/Runner/Info.plist` : ajout de `NSPhotoLibraryUsageDescription` (obligatoire pour `image_picker`, source galerie uniquement).
- Vérifié : projet iOS présent, bundle id `bf.salon.perruquesSalon`, déploiement iOS 13.0, aucun `DEVELOPMENT_TEAM` (signature à configurer sur Mac).

**Reste pour iOS :**
1. Configurer la signature (Team Apple) sur Mac.
2. `flutter build ipa` puis TestFlight.
3. Tester `sqflite`, `image_picker`, `share_plus`, `path_provider` sur iPhone réel.

## Suite session 4 — 23/10/2026 : refonte visuelle « Rose poudré & or »

**Réalisé :**
- `lib/theme/app_theme.dart` : palette (rose poudré, or, prune, crème), typo, champs, boutons, cartes, dialogs, bottom sheets, chips, snackbars unifiés.
- Widgets réutilisables : `stat_card.dart`, `empty_state.dart`, `section_header.dart`, `menu_card.dart` + `utils/format.dart` (FCFA, dates FR, initiales).
- Connexion : dégradé, carte, logo, mot de passe affichable, message d'erreur encadré.
- Dashboard unique admin/gestionnaire (`screens/dashboard/dashboard_screen.dart`) : salutation, date FR, CA du jour, stock bas, RDV du jour, grille d'actions colorées, pull-to-refresh. Anciens dashboards = wrappers.
- Stock : cartes avec photo, recherche + filtres + valeur du stock, formulaire **plein écran** (`stock_form_screen.dart`), menu Modifier/Supprimer, stock initial tracé en mouvement.
- Caisse : total en carte dégradée, formulaire en bottom sheet, type perruque/libre, chips de paiement, total live, états vides.
- Clients : recherche, avatars à initiales, points de fidélité, fiche détail, ajout en bottom sheet.
- RDV : groupés Aujourd'hui / À venir / Passés, badges de statut, ajout en bottom sheet, changement de statut et suppression.
- Stats : grille responsive (`Wrap`), best-sellers avec barres de progression, alertes stock.
- Utilisateurs : bottom sheet, rôle en `SegmentedButton`, doublon de téléphone géré.
- Historique stock : cartes + totaux entrées/sorties.

**Vérifications :** `flutter analyze` 0 issue, `flutter test` OK, `flutter build apk --release` OK → 51.0 MB (warning non bloquant `share_plus`/KGP).

**Test émulateur Android (1080×2400) :** APK installé, connexion admin `0000` / `admin123`, tous les écrans ouverts sans crash : dashboard, stock, formulaire article, caisse + bottom sheet, clients, RDV, stats, utilisateurs. Captures dans `captures/`. Chrome (`flutter run -d chrome`) n'est pas possible sans adaptation web (SQLite + `dart:io`).

**Reste :**
1. Tester visuellement sur téléphone réel (petits écrans) et ajuster si besoin.
2. Build iOS (Mac/Xcode + signature Apple).
3. Idée future : polices embarquées pour renforcer l'identité.
