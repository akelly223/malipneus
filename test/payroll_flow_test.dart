import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/data/local/database.dart';
import 'package:mali_pneus/data/repositories/payroll_repository_impl.dart';

/// Scénario 1 du cahier des charges : un employé gagne 150 000 F,
/// s'absente 2 jours (avec retenue) et reçoit une avance de 30 000 F.
/// Vérifie que la paie finale est correctement calculée et que
/// l'avance ne peut pas être déduite deux fois.
void main() {
  late AppDatabase db;
  late int employeeId;
  late int userId;
  late PayrollRepositoryImpl payrollRepo;

  setUp(() async {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Responsable',
            login: 'resp',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    final postes = await db.personnelDao.getAllJobPositions();
    final posteId = postes.first.id;
    employeeId = await db.personnelDao.createEmployee(
      EmployeesCompanion.insert(
        nom: 'Traoré',
        prenom: 'Moussa',
        posteId: posteId,
        dateEmbauche: DateTime(2025, 1, 1),
        salaireBase: const Value(150000),
      ),
    );
    payrollRepo = PayrollRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test(
      'retenue absence + avance correctement déduites du salaire net '
      '(150000 - 10000 - 30000 = 110000)', () async {
    // 2 jours d'absence avec retenue en août 2026.
    await db.personnelDao.createAbsence(
      EmployeeAbsencesCompanion.insert(
        employeeId: employeeId,
        dateDebut: DateTime(2026, 8, 5),
        dateFin: DateTime(2026, 8, 6),
        nombreJours: 2,
        motif: 'Maladie',
        userId: userId,
      ),
    );

    // Avance de 30 000 F.
    await payrollRepo.createAdvance(
      employeeId: employeeId,
      montant: 30000,
      date: DateTime(2026, 8, 10),
      motif: 'Avance sur salaire',
      userId: userId,
    );

    final periodId = await payrollRepo.createPeriod(
      libelle: 'Août 2026',
      dateDebut: DateTime(2026, 8, 1),
      dateFin: DateTime(2026, 8, 31),
      createdById: userId,
    );

    await payrollRepo.genererBulletinsPourPeriode(periodId);

    final payslips = await payrollRepo.getPayslipsForPeriod(periodId);
    expect(payslips, hasLength(1));
    final payslip = payslips.single;

    expect(payslip.salaireBase, 150000);
    expect(payslip.joursAbsence, 2);
    expect(payslip.retenueAbsence, 10000); // 150000/30*2
    expect(payslip.avancesDeduites, 30000);
    expect(payslip.salaireNet, 110000);
    expect(payslip.statutPaiement, 'non_paye');

    // L'avance est marquée consommée, rattachée à ce bulletin.
    final avances = await payrollRepo.getAdvancesForEmployee(employeeId);
    expect(avances.single.statut, 'consommee');
    expect(avances.single.payslipId, payslip.id);

    // Régénérer les bulletins de la même période ne crée pas de doublon
    // et ne redéduit pas l'avance déjà consommée.
    await payrollRepo.genererBulletinsPourPeriode(periodId);
    final payslipsApres = await payrollRepo.getPayslipsForPeriod(periodId);
    expect(payslipsApres, hasLength(1));
  });

  test('le règlement du bulletin met à jour le statut et l\'historique',
      () async {
    final periodId = await payrollRepo.createPeriod(
      libelle: 'Août 2026',
      dateDebut: DateTime(2026, 8, 1),
      dateFin: DateTime(2026, 8, 31),
      createdById: userId,
    );
    await payrollRepo.genererBulletinsPourPeriode(periodId);
    final payslip =
        (await payrollRepo.getPayslipsForPeriod(periodId)).single;
    expect(payslip.salaireNet, 150000);

    await payrollRepo.enregistrerPaiementBulletin(
      payslipId: payslip.id,
      montant: 150000,
      datePaiement: DateTime(2026, 9, 1),
      modePaiement: 'especes',
      payeParUserId: userId,
      payeParUserNom: 'Responsable',
    );

    final payslipPaye = await payrollRepo.getPayslipById(payslip.id);
    expect(payslipPaye!.statutPaiement, 'paye');
    expect(payslipPaye.montantPaye, 150000);

    final payments = await payrollRepo.getPaymentsForPayslip(payslip.id);
    expect(payments, hasLength(1));
    expect(payments.single.montant, 150000);
  });
}
