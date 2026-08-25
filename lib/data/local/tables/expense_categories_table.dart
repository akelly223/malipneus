import 'package:drift/drift.dart';

/// Catégories de dépenses, configurables par le responsable (seedées
/// avec une liste par défaut à la migration : Achat de pneus,
/// Chargement container, Transport, Transitaire, Douane, Manutention,
/// Loyer magasin, Électricité, Eau, Internet, Salaires, Avances sur
/// salaire, Commissions commerciales, Pertes, Réparations, Autres
/// dépenses).
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 100).unique()();

  BoolColumn get actif => boolean().withDefault(const Constant(true))();
}
