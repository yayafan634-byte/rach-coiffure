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

## Session 5 — 30/10/2026 : PWA iPhone + dispositions responsive + mise en ligne

**PWA / iPhone :**
- Vérifié : le projet compile en web (`flutter build web --release`).
- Ajout d'une bannière d'installation sur iPhone (`widgets/install_pwa_banner.dart`, `utils/install_pwa*.dart`) : affichée sur iOS hors mode standalone. Elle est cliquable et ouvre une aide en 4 étapes (Safari, Partager, Sur l'écran d'accueil, Ajouter) + bouton « Copier le lien ». Rappel : iOS n'expose aucun bouton « Installer » natif.
- Ajout de `netlify.toml` (publish `build/web`, cache service worker/wasm).
- Déploiement GitHub Pages effectué sur la branche `gh-pages` (build avec `--base-href /rach-coiffure/`).
- URL en ligne : https://yayafan634-byte.github.io/rach-coiffure/

**Dispositions responsive (mobile + tablette/desktop) :**
- Nouveau `navigation/app_section.dart` + `widgets/app_shell.dart` : barre latérale permanente ≥ 1024 px, drawer sur mobile, en-tête cohérent, menu compte (rôle + déconnexion), contenu plafonné à 1180 px.
- Routes nommées (`/dashboard`, `/stock`, ...) déclarées dans `main.dart`.
- Écrans Stock, Clients, Caisse, RDV, Stats, Utilisateurs migrés vers `AppShell`.
- Dashboard : salutation + grille d'accès rapides + bandeau rôle + alerte stock ; ancien drawer/menu supprimé.
- Connexion : layout en deux panneaux sur large écran (panneau marque + formulaire), empilé sur mobile.
- `recu_pdf.dart` : 9 `const` ajoutés (à nouveau 0 issue `flutter analyze`).

**Vérifications :** `flutter analyze` 0 issue, `flutter test` OK (1 test), `flutter build web --release` OK.

**À noter :** la mise en ligne utilise le build local ; le code source de cette session n'est pas encore commité sur `main`. Pour des mises à jour automatiques du site, il faudra committer et ajouter un workflow GitHub Actions (build + deploy `gh-pages`).

## Session 6 - 30/10/2026 : panier multi-articles, historique et autorisations

**Caisse / stock :**
- Mode sélection dans le Stock (icône checklist ou appui long) : cocher plusieurs articles, total en direct, puis « Encaisser » ouvre le panier pré-rempli.
- ouvrirEncaissement(...) réutilisable, panier passé à EncaissementSheet.lignesInitiales.

**Historique :**
- Nouvel écran admin screens/admin/historique_screen.dart (section /historique) : recherche, filtres Aujourd'hui/7 jours/Tout, filtre par utilisateur, regroupement par jour, purge avec confirmation.
- Journalisation : connexions/déconnexions, ventes (déjà), articles ajoutés/modifiés/supprimés, clients, rendez-vous, comptes créés/désactivés, autorisations modifiées, exports CSV/PDF.

**Autorisations :**
- models/permission.dart (7 permissions), colonne users.permissions (DB v5, ALTER TABLE à la migration).
- Admin = toutes les permissions ; gestionnaire = ensemble coché à la création ou modifiable ensuite via l'icône réglages.
- Navigation, dashboard, routes et actions sensibles (suppressions, exports) filtrés via AuthProvider.peut(...).

**Vérifications :** dart format, lutter analyze 0 issue, lutter test OK, lutter build web --release OK.

**À noter :** source toujours non commitée sur main ; site mis à jour via la branche gh-pages.

## Session 7 - 07/11/2026 : audit et durcissement

**Audit :** rapport complet remis (sécurité, bugs de données, dette technique). `flutter analyze` 0 issue, `flutter test` OK.

**Sécurité :**
- Mot de passe admin initial `0000`/`admin123` désormais marqué « à changer » (DB v7, colonne `users.doitChangerMotDePasse`), écran de changement obligatoire après connexion et pour les installations existantes utilisant encore le mot de passe par défaut.
- Politique de mot de passe : 8 caractères minimum, au moins une lettre et un chiffre (`validerMotDePasse`).
- Limitation des tentatives de connexion : 5 échecs = blocage temporaire 5 min (mémoire de session).
- Nouveau menu « Changer mon mot de passe » et réinitialisation par l'admin (changement forcé à la prochaine connexion).
- Restauration de sauvegarde refusée si la sauvegarde ne contient aucun administrateur valide (évite de verrouiller l'application).
- `PRAGMA foreign_keys = ON` activé (`onConfigure`) ; suppression d'article nettoie désormais les mouvements de stock et la photo, et `ventesLiees` compte aussi les lignes `venteItems`.
- Suppression de fiche client ajoutée (permission `suppressions`) avec blocage si ventes ou rendez-vous liés.

**Bugs corrigés :**
- `stock_form_screen.dart` : `seuilAlerte` et `fournisseur` ne sont plus réinitialisés (champs éditables), mise à jour fiche + mouvement de stock dans une seule transaction, ancienne photo supprimée.
- `client_form_sheet.dart` : `dateNaissance` conservée et éditable via sélecteur de date.
- Chaînes corrompues corrigées dans `dashboard_screen.dart` et `rdv_screen.dart`.
- Tests modèles ajoutés (`test/models_test.dart`).

**Reste à faire manuellement :** révoquer/rotationner la clé `service_role` dans Supabase puis supprimer `cle.txt`, configurer la signature release Android, valider la migration DB sur une copie de données réelles.

## Session 8 - 08/11/2026 : son, synchro multi-téléphones et grille du jour

**Réalisé :**
- Son d'encaissement : `SonService.initialiser()` précharge `assets/sounds/succes.wav` au démarrage, puis `succes()` rejoue immédiatement sans recharger l'asset (fallback `play` si besoin).
- Synchronisation multi-appareils Supabase :
  - `lib/config/supabase_config.dart` (URL + clé publishable, surchargeables par `--dart-define`).
  - `lib/services/cloud_sync.dart` : instantané JSON de la base locale stocké dans `public.cloud_sync`, envoi automatique toutes les 20 s et après chaque encaissement, réception au démarrage / via le bouton cloud / à la reprise.
  - `main.dart` initialise le son puis la synchro avant la connexion, et pousse les données à la mise en pause.
  - Icône « Synchroniser avec le cloud » ajoutée sur le tableau de bord.
  - `AndroidManifest.xml` : permission `INTERNET` ajoutée pour les builds release.
  - `supabase/schema.sql` : table `cloud_sync` + politique RLS `anon`/`authenticated`. **À exécuter une fois dans Supabase > SQL Editor.**
- Accueil du jour : la grille « Aperçu du jour » passe en 2 colonnes sur téléphone (seuil 320 px au lieu de 420 px).
- `file_picker` retiré du `pubspec.yaml` : dépendance inutilisée qui empêchait la compilation APK avec AGP 9 / Kotlin intégré.

**Vérifications :** `flutter analyze` 0 issue, `flutter test` OK (7 tests), `flutter build web --release` OK, `flutter build apk --release` OK (63,3 Mo). APK : `RachCoiffure-1.0.0-sync.apk`.

**Reste à faire :** coller/exécuter `supabase/schema.sql` dans Supabase, puis tester deux téléphones (saisie + encaissement sur l'un, réouverture ou bouton cloud sur l'autre).
