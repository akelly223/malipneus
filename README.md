# MaliPneus (Flutter Desktop Windows)

Logiciel de gestion commerciale desktop pour un vendeur de pneus et pièces
automobiles au Mali. Basé sur le socle **MaliStock** (`gestion_commerciale`),
cloné le 2026-08-16 comme point de départ pour des fonctionnalités
spécifiques au métier du pneu (à définir).

Éditeur : MALI_CODE CENTER.

## Ce qui vient du socle MaliStock

Application desktop offline (SQLite locale via Drift), Clean Architecture
(`domain` → entités/interfaces, `data` → Drift + repositories,
`presentation` → écrans + providers Riverpod), navigation GoRouter avec
sidebar persistante. Modules déjà en place : authentification (admin +
employés avec permissions), articles/catégories, stock multi-magasin,
clients/fournisseurs, devis, factures (PDF), achats fournisseurs (bons de
commande), dettes clients, inventaire (comptage physique + export/import),
sauvegarde/restauration ZIP, tableau de bord.

Le module « dépôt-vente auteurs » (spécifique à la vente de livres) a été
retiré de l'interface : le bouton qui permettait de marquer un fournisseur
comme auteur en dépôt-vente a été supprimé, la fonctionnalité est donc
inaccessible depuis l'UI. Le code et le schéma de base sous-jacents n'ont
pas été touchés (colonnes `estDepot` / `partAuteurPct` toujours présentes
mais inertes) pour ne pas fragiliser la migration Drift.

## Mise en place de l'environnement

### Prérequis

1. **Flutter SDK** (canal stable, ≥ 3.22) installé et dans le PATH — vérifier avec `flutter --version`
2. Activer le support desktop Windows :
   ```
   flutter config --enable-windows-desktop
   ```
3. **Visual Studio 2022** avec le workload "Desktop development with C++"
4. Vérifier l'environnement :
   ```
   flutter doctor
   ```

### Étapes

1. Ouvre un terminal dans le dossier `mali_pneus/`
2. Installe les dépendances :
   ```
   flutter pub get
   ```
3. Génère le code Drift/Riverpod (fichiers `.g.dart`, non versionnés) :
   ```
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Génère le squelette natif Windows s'il manque :
   ```
   flutter create --platforms=windows .
   ```
5. Lance l'application en mode développement :
   ```
   flutter run -d windows
   ```
   ou pour un build final :
   ```
   flutter build windows
   ```

### En cas d'erreur

- **Visual Studio C++ manquant** → l'installer via Visual Studio Installer, relancer `flutter doctor`.
- **sqlite3_flutter_libs introuvable** → `flutter clean && flutter pub get`.
- **Conflits build_runner** → toujours utiliser `--delete-conflicting-outputs`.
- **Premier lancement** : aucun utilisateur n'existe en base, l'écran de connexion proposera automatiquement de créer le compte administrateur.

## Prochaine étape

Fonctionnalités spécifiques pneus/pièces auto à définir avec le client
(ex : dimensions/référence pneu, saisonnalité, compatibilité véhicule).
