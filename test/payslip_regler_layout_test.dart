import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/app/providers/repository_providers.dart';
import 'package:mali_pneus/app/providers/session_provider.dart';
import 'package:mali_pneus/data/local/database.dart';
import 'package:mali_pneus/data/repositories/payroll_repository_impl.dart';
import 'package:mali_pneus/domain/entities/user.dart';
import 'package:mali_pneus/presentation/payroll/payslip_detail_screen.dart';

/// Régression : cliquer sur "Régler" sur un bulletin de paie affichait
/// un champ "Date" non contraint en largeur dans une Row (InkWell /
/// InputDecorator hors d'un Expanded), ce qui provoque une exception de
/// layout ("An InputDecorator ... cannot have an unbounded width"). Non
/// rattrapée, cette exception laissait des RenderObject jamais mis en
/// page, et le hit-test suivant du MouseTracker plantait à son tour en
/// bloquant l'app entière jusqu'au redémarrage. Ce test rend l'écran
/// réel (pas une reconstruction simplifiée) et clique réellement sur
/// "Régler" pour s'assurer que ce chemin ne remet jamais cette
/// exception de layout.
void main() {
  testWidgets(
      'Bulletin de paie : cliquer sur Régler affiche le formulaire sans '
      'exception de layout', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Responsable',
            login: 'resp',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    final postes = await db.personnelDao.getAllJobPositions();
    final employeeId = await db.personnelDao.createEmployee(
      EmployeesCompanion.insert(
        nom: 'Keita',
        prenom: 'Moussa',
        posteId: postes.first.id,
        dateEmbauche: DateTime(2025, 1, 1),
        salaireBase: const Value(150000),
      ),
    );
    final payrollRepo = PayrollRepositoryImpl(db);
    final periodId = await payrollRepo.createPeriod(
      libelle: 'Août 2026',
      dateDebut: DateTime(2026, 8, 1),
      dateFin: DateTime(2026, 8, 31),
      createdById: userId,
    );
    await payrollRepo.genererBulletinsPourPeriode(periodId);
    final payslip = (await payrollRepo.getPayslipsForPeriod(periodId)).single;
    expect(payslip.employeeId, employeeId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => SessionNotifier()
            ..setUser(UserEntity(
              id: userId,
              nom: 'Responsable',
              login: 'resp',
              role: 'admin',
              actif: true,
              dateCreation: DateTime(2026),
            ))),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR')],
          locale: const Locale('fr', 'FR'),
          home: PayslipDetailScreen(payslipId: payslip.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reglerButton = find.widgetWithText(ElevatedButton, 'Régler');
    await tester.ensureVisible(reglerButton);
    await tester.pumpAndSettle();
    await tester.tap(reglerButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Confirmer le paiement'), findsOneWidget);
    expect(find.text('Date'), findsWidgets);
  });
}
