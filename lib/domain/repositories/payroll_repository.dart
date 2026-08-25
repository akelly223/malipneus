import '../entities/payroll.dart';

abstract class PayrollRepository {
  Future<PayrollSettingsEntity> getSettings();
  Future<void> saveSettings(double joursTheoriquesParMois);

  Future<List<PayrollPeriodEntity>> getAllPeriods();
  Future<PayrollPeriodEntity?> getPeriodById(int id);
  Future<int> createPeriod({
    required String libelle,
    required DateTime dateDebut,
    required DateTime dateFin,
    int? createdById,
  });

  Future<List<PayslipEntity>> getPayslipsForPeriod(int payrollPeriodId);
  Future<List<PayslipEntity>> getPayslipsForEmployee(int employeeId);
  Future<PayslipEntity?> getPayslipById(int id);

  /// Génère les bulletins de tous les employés actifs qui n'en ont pas
  /// encore pour cette période : calcule la retenue d'absence (règle
  /// configurée dans [PayrollSettings]) et déduit les avances actives
  /// de chaque employé (marquées "consommées" pour ne jamais être
  /// redéduites sur une autre paie).
  Future<void> genererBulletinsPourPeriode(int payrollPeriodId);

  /// Ajuste manuellement un bulletin (bonus, autres déductions,
  /// ajustement +/-) — une justification est requise pour
  /// l'ajustement manuel.
  Future<void> ajusterBulletin({
    required int payslipId,
    double? bonus,
    double? autresDeductions,
    double? ajustementManuel,
    String? justificationAjustement,
  });

  Future<void> enregistrerPaiementBulletin({
    required int payslipId,
    required double montant,
    required DateTime datePaiement,
    required String modePaiement,
    required int payeParUserId,
    String? payeParUserNom,
  });

  Future<List<PayslipPaymentEntity>> getPaymentsForPayslip(int payslipId);

  Future<List<SalaryAdvanceEntity>> getAdvancesForEmployee(int employeeId);
  Future<int> createAdvance({
    required int employeeId,
    required double montant,
    required DateTime date,
    String? motif,
    required int userId,
  });
  Future<void> annulerAvance(int advanceId);
}
