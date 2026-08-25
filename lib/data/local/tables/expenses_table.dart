import 'package:drift/drift.dart';
import 'expense_categories_table.dart';
import 'loadings_table.dart';
import 'articles_table.dart';
import 'users_table.dart';

/// Une dépense de l'entreprise (module Dépenses).
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categorieId => integer().references(ExpenseCategories, #id)();

  RealColumn get montant => real()();
  DateTimeColumn get date => dateTime()();

  TextColumn get description => text().nullable()();

  /// Fournisseur ou personne concernée par cette dépense, si applicable.
  TextColumn get fournisseurOuPersonne => text().nullable()();

  /// Chargement concerné, si cette dépense lui est imputable (transport,
  /// douane, transitaire, manutention...).
  IntColumn get chargementId =>
      integer().nullable().references(Loadings, #id)();

  /// Pneu concerné, si cette dépense est imputable à une référence
  /// précise plutôt qu'à un chargement entier ou une dépense générale.
  IntColumn get articleId =>
      integer().nullable().references(Articles, #id)();

  /// Méthode de répartition d'une dépense PARTAGÉE (articleId null,
  /// chargementId non null) entre les lignes d'achat du chargement :
  /// 'quantite' | 'valeur_achat' | 'poids' | 'manuelle'. Sans effet si
  /// la dépense est directe (articleId renseigné) ou hors chargement.
  TextColumn get methodeAllocation =>
      text().withDefault(const Constant('quantite'))();

  /// Chemin du fichier justificatif copié dans le dossier de données de
  /// l'application (même pattern que app_settings.signature_path).
  TextColumn get pieceJustificativePath => text().nullable()();

  IntColumn get createdById => integer().nullable().references(Users, #id)();
  TextColumn get createdByNom => text().nullable()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
