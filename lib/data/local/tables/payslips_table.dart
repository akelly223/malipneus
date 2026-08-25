import 'package:drift/drift.dart';
import 'payroll_periods_table.dart';
import 'employees_table.dart';

/// Bulletin de paie d'un employé pour une période donnée.
///
/// Formule : salaire_net = salaire_base + bonus - retenue_absence -
/// avances_deduites - autres_deductions + ajustement_manuel.
///
/// Tous les montants sont figés au moment de la génération (snapshot),
/// à l'exception de [montantPaye]/[statutPaiement] mis à jour par les
/// règlements (voir [PayslipPayments]). Une paie payée n'est jamais
/// supprimée — c'est un historique immuable.
class Payslips extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get payrollPeriodId =>
      integer().references(PayrollPeriods, #id)();
  IntColumn get employeeId => integer().references(Employees, #id)();

  RealColumn get salaireBase => real()();

  /// Jours théoriquement travaillés sur la période (issu de
  /// [PayrollSettings] au moment de la génération).
  RealColumn get joursTheoriques => real()();

  RealColumn get joursAbsence => real().withDefault(const Constant(0))();
  RealColumn get retenueAbsence => real().withDefault(const Constant(0))();
  RealColumn get avancesDeduites => real().withDefault(const Constant(0))();
  RealColumn get bonus => real().withDefault(const Constant(0))();
  RealColumn get autresDeductions => real().withDefault(const Constant(0))();

  /// Ajustement manuel du responsable (+/-), justifié obligatoirement.
  RealColumn get ajustementManuel => real().withDefault(const Constant(0))();
  TextColumn get justificationAjustement => text().nullable()();

  RealColumn get salaireNet => real()();

  RealColumn get montantPaye => real().withDefault(const Constant(0))();

  /// 'non_paye' | 'partiel' | 'paye'
  TextColumn get statutPaiement =>
      text().withDefault(const Constant('non_paye'))();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {payrollPeriodId, employeeId},
      ];
}
