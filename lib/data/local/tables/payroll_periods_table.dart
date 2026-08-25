import 'package:drift/drift.dart';
import 'users_table.dart';

/// Une période de paie (ex: "Août 2026"), regroupe les bulletins
/// ([Payslips]) de tous les employés pour cette période. Les commerciaux
/// ne sont PAS nécessairement payés selon les mêmes périodes (voir
/// [CommissionSettlements], indépendant de cette table).
class PayrollPeriods extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get libelle => text().withLength(min: 1, max: 100)();

  DateTimeColumn get dateDebut => dateTime()();
  DateTimeColumn get dateFin => dateTime()();

  /// 'ouverte' | 'cloturee'
  TextColumn get statut => text().withDefault(const Constant('ouverte'))();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  IntColumn get createdById => integer().nullable().references(Users, #id)();
}
