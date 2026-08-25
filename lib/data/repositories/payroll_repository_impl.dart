import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/payroll.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../../core/constants/db_constants.dart';

class PayrollRepositoryImpl implements PayrollRepository {
  final AppDatabase db;

  PayrollRepositoryImpl(this.db);

  // ── Paramètres ────────────────────────────────────────────────────────────

  @override
  Future<PayrollSettingsEntity> getSettings() async {
    final row = await db.payrollDao.getSettings();
    if (row == null) return const PayrollSettingsEntity();
    return PayrollSettingsEntity(
      joursTheoriquesParMois: row.joursTheoriquesParMois,
      dateModification: row.dateModification,
    );
  }

  @override
  Future<void> saveSettings(double joursTheoriquesParMois) =>
      db.payrollDao.saveSettings(joursTheoriquesParMois);

  // ── Périodes ──────────────────────────────────────────────────────────────

  @override
  Future<List<PayrollPeriodEntity>> getAllPeriods() async {
    final rows = await db.payrollDao.getAllPeriods();
    return rows.map(_periodToEntity).toList();
  }

  @override
  Future<PayrollPeriodEntity?> getPeriodById(int id) async {
    final row = await db.payrollDao.getPeriodById(id);
    return row == null ? null : _periodToEntity(row);
  }

  PayrollPeriodEntity _periodToEntity(PayrollPeriod p) => PayrollPeriodEntity(
        id: p.id,
        libelle: p.libelle,
        dateDebut: p.dateDebut,
        dateFin: p.dateFin,
        statut: p.statut,
        dateCreation: p.dateCreation,
      );

  @override
  Future<int> createPeriod({
    required String libelle,
    required DateTime dateDebut,
    required DateTime dateFin,
    int? createdById,
  }) =>
      db.payrollDao.createPeriod(PayrollPeriodsCompanion.insert(
        libelle: libelle,
        dateDebut: dateDebut,
        dateFin: dateFin,
        createdById: Value(createdById),
      ));

  // ── Bulletins ─────────────────────────────────────────────────────────────

  Future<PayslipEntity> _payslipToEntity(Payslip p) async {
    final employee = await db.personnelDao.getEmployeeById(p.employeeId);
    return PayslipEntity(
      id: p.id,
      payrollPeriodId: p.payrollPeriodId,
      employeeId: p.employeeId,
      employeeNomComplet:
          employee != null ? '${employee.prenom} ${employee.nom}' : null,
      salaireBase: p.salaireBase,
      joursTheoriques: p.joursTheoriques,
      joursAbsence: p.joursAbsence,
      retenueAbsence: p.retenueAbsence,
      avancesDeduites: p.avancesDeduites,
      bonus: p.bonus,
      autresDeductions: p.autresDeductions,
      ajustementManuel: p.ajustementManuel,
      justificationAjustement: p.justificationAjustement,
      salaireNet: p.salaireNet,
      montantPaye: p.montantPaye,
      statutPaiement: p.statutPaiement,
      dateCreation: p.dateCreation,
    );
  }

  @override
  Future<List<PayslipEntity>> getPayslipsForPeriod(
      int payrollPeriodId) async {
    final rows = await db.payrollDao.getPayslipsForPeriod(payrollPeriodId);
    final result = <PayslipEntity>[];
    for (final r in rows) {
      result.add(await _payslipToEntity(r));
    }
    return result;
  }

  @override
  Future<List<PayslipEntity>> getPayslipsForEmployee(int employeeId) async {
    final rows = await db.payrollDao.getPayslipsForEmployee(employeeId);
    final result = <PayslipEntity>[];
    for (final r in rows) {
      result.add(await _payslipToEntity(r));
    }
    return result;
  }

  @override
  Future<PayslipEntity?> getPayslipById(int id) async {
    final row = await db.payrollDao.getPayslipById(id);
    return row == null ? null : _payslipToEntity(row);
  }

  /// Formule : salaire_net = salaire_base + bonus - retenue_absence -
  /// avances_deduites - autres_deductions + ajustement_manuel.
  ///
  /// Génère un bulletin uniquement pour les employés actifs qui n'en
  /// ont pas déjà un pour cette période (clé unique en base, protège
  /// aussi contre un double-clic). Les avances actives de l'employé
  /// sont intégralement déduites et marquées "consommées" — elles ne
  /// pourront plus être sélectionnées sur une autre paie.
  @override
  Future<void> genererBulletinsPourPeriode(int payrollPeriodId) async {
    final period = await db.payrollDao.getPeriodById(payrollPeriodId);
    if (period == null) throw Exception('Période de paie introuvable');

    final settings = await getSettings();
    final employees = await db.personnelDao.getActiveEmployees();

    await db.transaction(() async {
      for (final employee in employees) {
        final existant = await db.payrollDao
            .getPayslipForEmployeeAndPeriod(employee.id, payrollPeriodId);
        if (existant != null) continue;

        final absences = await db.personnelDao
            .getAbsencesAvecRetenueDansPeriode(
          employeeId: employee.id,
          debut: period.dateDebut,
          fin: period.dateFin,
        );
        final joursAbsence =
            absences.fold<double>(0, (s, a) => s + a.nombreJours);
        final retenueAbsence = settings.joursTheoriquesParMois > 0
            ? employee.salaireBase /
                settings.joursTheoriquesParMois *
                joursAbsence
            : 0.0;

        final avancesActives =
            await db.payrollDao.getActiveAdvancesForEmployee(employee.id);
        final avancesDeduites =
            avancesActives.fold<double>(0, (s, a) => s + a.montant);

        final salaireNet =
            employee.salaireBase - retenueAbsence - avancesDeduites;

        final payslipId = await db.payrollDao.createPayslip(
          PayslipsCompanion.insert(
            payrollPeriodId: payrollPeriodId,
            employeeId: employee.id,
            salaireBase: employee.salaireBase,
            joursTheoriques: settings.joursTheoriquesParMois,
            joursAbsence: Value(joursAbsence),
            retenueAbsence: Value(retenueAbsence),
            avancesDeduites: Value(avancesDeduites),
            salaireNet: salaireNet,
          ),
        );

        for (final avance in avancesActives) {
          await db.payrollDao.marquerAvanceConsommee(avance.id, payslipId);
        }
      }
    });
  }

  @override
  Future<void> ajusterBulletin({
    required int payslipId,
    double? bonus,
    double? autresDeductions,
    double? ajustementManuel,
    String? justificationAjustement,
  }) async {
    final payslip = await db.payrollDao.getPayslipById(payslipId);
    if (payslip == null) throw Exception('Bulletin introuvable');

    final nouveauBonus = bonus ?? payslip.bonus;
    final nouvellesAutresDeductions =
        autresDeductions ?? payslip.autresDeductions;
    final nouvelAjustement = ajustementManuel ?? payslip.ajustementManuel;

    final nouveauSalaireNet = payslip.salaireBase +
        nouveauBonus -
        payslip.retenueAbsence -
        payslip.avancesDeduites -
        nouvellesAutresDeductions +
        nouvelAjustement;

    await (db.update(db.payslips)..where((p) => p.id.equals(payslipId)))
        .write(PayslipsCompanion(
      bonus: Value(nouveauBonus),
      autresDeductions: Value(nouvellesAutresDeductions),
      ajustementManuel: Value(nouvelAjustement),
      justificationAjustement: Value(
          justificationAjustement ?? payslip.justificationAjustement),
      salaireNet: Value(nouveauSalaireNet),
    ));
  }

  @override
  Future<void> enregistrerPaiementBulletin({
    required int payslipId,
    required double montant,
    required DateTime datePaiement,
    required String modePaiement,
    required int payeParUserId,
    String? payeParUserNom,
  }) async {
    final payslip = await db.payrollDao.getPayslipById(payslipId);
    if (payslip == null) throw Exception('Bulletin introuvable');

    await db.transaction(() async {
      await db.payrollDao.createPayslipPayment(
        PayslipPaymentsCompanion.insert(
          payslipId: payslipId,
          montant: montant,
          datePaiement: datePaiement,
          modePaiement: Value(modePaiement),
          payeParUserId: payeParUserId,
          payeParUserNom: Value(payeParUserNom),
        ),
      );

      final nouveauMontantPaye = payslip.montantPaye + montant;
      final statut = nouveauMontantPaye >= payslip.salaireNet - 0.01
          ? DbConstants.invoiceStatusPaye
          : (nouveauMontantPaye > 0
              ? DbConstants.invoiceStatusPartiel
              : DbConstants.invoiceStatusNonPaye);

      await db.payrollDao
          .updatePaiementPayslip(payslipId, nouveauMontantPaye, statut);
    });
  }

  @override
  Future<List<PayslipPaymentEntity>> getPaymentsForPayslip(
      int payslipId) async {
    final rows = await db.payrollDao.getPaymentsForPayslip(payslipId);
    return rows
        .map((p) => PayslipPaymentEntity(
              id: p.id,
              payslipId: p.payslipId,
              montant: p.montant,
              datePaiement: p.datePaiement,
              modePaiement: p.modePaiement,
              payeParUserId: p.payeParUserId,
              payeParUserNom: p.payeParUserNom,
              dateCreation: p.dateCreation,
            ))
        .toList();
  }

  // ── Avances ───────────────────────────────────────────────────────────────

  @override
  Future<List<SalaryAdvanceEntity>> getAdvancesForEmployee(
      int employeeId) async {
    final rows = await db.payrollDao.getAdvancesForEmployee(employeeId);
    return rows
        .map((a) => SalaryAdvanceEntity(
              id: a.id,
              employeeId: a.employeeId,
              montant: a.montant,
              date: a.date,
              motif: a.motif,
              statut: a.statut,
              payslipId: a.payslipId,
              userId: a.userId,
              dateCreation: a.dateCreation,
            ))
        .toList();
  }

  @override
  Future<int> createAdvance({
    required int employeeId,
    required double montant,
    required DateTime date,
    String? motif,
    required int userId,
  }) =>
      db.payrollDao.createAdvance(SalaryAdvancesCompanion.insert(
        employeeId: employeeId,
        montant: montant,
        date: date,
        motif: Value(motif),
        userId: userId,
      ));

  @override
  Future<void> annulerAvance(int advanceId) =>
      db.payrollDao.annulerAvance(advanceId);
}
