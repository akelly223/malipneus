import 'package:drift/drift.dart';
import 'employees_table.dart';
import 'articles_table.dart';
import 'categories_table.dart';

/// Règle de commission spécifique à un article ou une catégorie pour
/// un commercial donné, prioritaire sur [CommissionConfigs] au moment
/// du calcul de la commission à la vente.
class CommissionConfigOverrides extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  IntColumn get articleId =>
      integer().nullable().references(Articles, #id)();
  IntColumn get categorieId =>
      integer().nullable().references(Categories, #id)();

  /// 'fixe' | 'pourcentage'
  TextColumn get typeCommission => text()();

  RealColumn get montantFixe => real().nullable()();
  RealColumn get pourcentage => real().nullable()();
}
