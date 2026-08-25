import 'package:drift/drift.dart';
import 'employees_table.dart';

/// Configuration de rémunération commerciale d'un employé (un
/// commercial). Une seule configuration active par employé ; pour des
/// règles différentes selon le produit, voir
/// [CommissionConfigOverrides].
class CommissionConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId =>
      integer().references(Employees, #id).unique()();

  /// 'fixe' | 'pourcentage'
  TextColumn get typeCommission => text()();

  /// Utilisé si typeCommission = 'fixe' : montant fixe par pneu vendu.
  RealColumn get montantFixeParPneu => real().nullable()();

  /// Utilisé si typeCommission = 'pourcentage' : % du prix de vente HT.
  RealColumn get pourcentage => real().nullable()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dateModification => dateTime().nullable()();
}
