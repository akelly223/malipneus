import 'package:drift/drift.dart';
import 'employees_table.dart';
import 'payslips_table.dart';
import 'users_table.dart';

/// Avance sur salaire. Quand une paie est générée pour la période
/// concernée, les avances actives de l'employé sont déduites du
/// salaire net et rattachées au bulletin via [payslipId] — une avance
/// consommée ne peut plus être sélectionnée pour une autre paie
/// (garde anti double-déduction, même principe que
/// [DocumentLines.commissionSettlementId]).
class SalaryAdvances extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  RealColumn get montant => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get motif => text().nullable()();

  /// 'active' | 'consommee' | 'annulee'
  TextColumn get statut => text().withDefault(const Constant('active'))();

  /// Renseigné quand l'avance est déduite d'un bulletin de paie.
  IntColumn get payslipId => integer().nullable().references(Payslips, #id)();

  IntColumn get userId => integer().references(Users, #id)();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
