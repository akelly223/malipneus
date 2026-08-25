import 'package:drift/drift.dart';
import 'employees_table.dart';
import 'users_table.dart';

/// Absences d'un employé, prises en compte dans le calcul de la paie
/// (voir [PayrollSettings] pour la règle de retenue configurable).
class EmployeeAbsences extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  DateTimeColumn get dateDebut => dateTime()();
  DateTimeColumn get dateFin => dateTime()();

  /// Peut être fractionnaire (demi-journée).
  RealColumn get nombreJours => real()();

  TextColumn get motif => text()();

  BoolColumn get justifiee => boolean().withDefault(const Constant(true))();

  /// Si vrai, cette absence génère une retenue sur la paie de la
  /// période concernée.
  BoolColumn get avecRetenue => boolean().withDefault(const Constant(true))();

  TextColumn get commentaire => text().nullable()();

  IntColumn get userId => integer().references(Users, #id)();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
