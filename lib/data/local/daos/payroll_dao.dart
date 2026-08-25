import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/payroll_settings_table.dart';
import '../tables/payroll_periods_table.dart';
import '../tables/payslips_table.dart';
import '../tables/payslip_payments_table.dart';
import '../tables/salary_advances_table.dart';

part 'payroll_dao.g.dart';

@DriftAccessor(tables: [
  PayrollSettings,
  PayrollPeriods,
  Payslips,
  PayslipPayments,
  SalaryAdvances,
])
class PayrollDao extends DatabaseAccessor<AppDatabase>
    with _$PayrollDaoMixin {
  PayrollDao(super.db);

  // ── Paramètres (singleton id=1) ─────────────────────────────────────────

  Future<PayrollSetting?> getSettings() =>
      (select(payrollSettings)..where((s) => s.id.equals(1)))
          .getSingleOrNull();

  Future<void> saveSettings(double joursTheoriquesParMois) async {
    final existant = await getSettings();
    if (existant == null) {
      await into(payrollSettings).insert(PayrollSettingsCompanion.insert(
        joursTheoriquesParMois: Value(joursTheoriquesParMois),
        dateModification: Value(DateTime.now()),
      ));
    } else {
      await (update(payrollSettings)..where((s) => s.id.equals(1))).write(
        PayrollSettingsCompanion(
          joursTheoriquesParMois: Value(joursTheoriquesParMois),
          dateModification: Value(DateTime.now()),
        ),
      );
    }
  }

  // ── Périodes de paie ─────────────────────────────────────────────────────

  Future<List<PayrollPeriod>> getAllPeriods() => (select(payrollPeriods)
        ..orderBy([(p) => OrderingTerm.desc(p.dateDebut)]))
      .get();

  Future<PayrollPeriod?> getPeriodById(int id) =>
      (select(payrollPeriods)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  Future<int> createPeriod(PayrollPeriodsCompanion period) =>
      into(payrollPeriods).insert(period);

  // ── Bulletins ─────────────────────────────────────────────────────────────

  Future<List<Payslip>> getPayslipsForPeriod(int payrollPeriodId) =>
      (select(payslips)
            ..where((p) => p.payrollPeriodId.equals(payrollPeriodId)))
          .get();

  Future<List<Payslip>> getPayslipsForEmployee(int employeeId) =>
      (select(payslips)
            ..where((p) => p.employeeId.equals(employeeId))
            ..orderBy([(p) => OrderingTerm.desc(p.dateCreation)]))
          .get();

  Future<Payslip?> getPayslipById(int id) =>
      (select(payslips)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Payslip?> getPayslipForEmployeeAndPeriod(
          int employeeId, int payrollPeriodId) =>
      (select(payslips)
            ..where((p) =>
                p.employeeId.equals(employeeId) &
                p.payrollPeriodId.equals(payrollPeriodId)))
          .getSingleOrNull();

  Future<int> createPayslip(PayslipsCompanion payslip) =>
      into(payslips).insert(payslip);

  Future<void> updatePaiementPayslip(
    int payslipId,
    double montantPaye,
    String statutPaiement,
  ) =>
      (update(payslips)..where((p) => p.id.equals(payslipId))).write(
        PayslipsCompanion(
          montantPaye: Value(montantPaye),
          statutPaiement: Value(statutPaiement),
        ),
      );

  // ── Règlements de paie ────────────────────────────────────────────────────

  Future<List<PayslipPayment>> getPaymentsForPayslip(int payslipId) =>
      (select(payslipPayments)..where((p) => p.payslipId.equals(payslipId)))
          .get();

  Future<int> createPayslipPayment(PayslipPaymentsCompanion payment) =>
      into(payslipPayments).insert(payment);

  // ── Avances sur salaire ───────────────────────────────────────────────────

  Future<List<SalaryAdvance>> getAdvancesForEmployee(int employeeId) =>
      (select(salaryAdvances)
            ..where((a) => a.employeeId.equals(employeeId))
            ..orderBy([(a) => OrderingTerm.desc(a.date)]))
          .get();

  /// Avances actives (non encore consommées par une paie) d'un employé.
  Future<List<SalaryAdvance>> getActiveAdvancesForEmployee(int employeeId) =>
      (select(salaryAdvances)
            ..where((a) =>
                a.employeeId.equals(employeeId) & a.statut.equals('active')))
          .get();

  Future<int> createAdvance(SalaryAdvancesCompanion advance) =>
      into(salaryAdvances).insert(advance);

  /// Marque une avance comme consommée par un bulletin de paie — ne
  /// peut plus être sélectionnée pour une autre paie (anti double
  /// déduction).
  Future<void> marquerAvanceConsommee(int advanceId, int payslipId) =>
      (update(salaryAdvances)..where((a) => a.id.equals(advanceId))).write(
        SalaryAdvancesCompanion(
          statut: const Value('consommee'),
          payslipId: Value(payslipId),
        ),
      );

  Future<void> annulerAvance(int advanceId) =>
      (update(salaryAdvances)..where((a) => a.id.equals(advanceId))).write(
        const SalaryAdvancesCompanion(statut: Value('annulee')),
      );
}
