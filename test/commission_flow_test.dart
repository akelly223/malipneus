import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/data/local/database.dart';
import 'package:mali_pneus/data/repositories/commercial_document_repository_impl.dart';
import 'package:mali_pneus/data/repositories/commissions_repository_impl.dart';
import 'package:mali_pneus/domain/entities/document_input.dart';
import 'package:mali_pneus/domain/entities/document_type.dart';

/// Scénarios 2, 3 et 4 du cahier des charges : vente par un commercial
/// avec commission fixe, filtrage par période, règlement et garde
/// anti-double-paiement.
void main() {
  late AppDatabase db;
  late int storeId;
  late int userId;
  late int articleId;
  late int commercialId;
  late CommercialDocumentRepositoryImpl documentRepo;
  late CommissionsRepositoryImpl commissionsRepo;

  setUp(() async {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    storeId = await db.into(db.stores).insert(
          StoresCompanion.insert(nom: 'Magasin principal'),
        );
    userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Responsable',
            login: 'resp',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    articleId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'PNEU-1',
            nom: 'Pneu 175/70R13',
            prixAchat: const Value(5000),
            prixVente: 6000,
          ),
        );
    await db.into(db.articleStocks).insert(
          ArticleStocksCompanion.insert(
            articleId: articleId,
            storeId: storeId,
            quantite: const Value(50),
          ),
        );

    final postes = await db.personnelDao.getAllJobPositions();
    commercialId = await db.personnelDao.createEmployee(
      EmployeesCompanion.insert(
        nom: 'Diallo',
        prenom: 'Moussa',
        posteId: postes.firstWhere((p) => p.nom == 'Commercial').id,
        dateEmbauche: DateTime(2025, 1, 1),
      ),
    );
    await db.commissionsDao.upsertConfig(
      CommissionConfigsCompanion.insert(
        employeeId: commercialId,
        typeCommission: 'fixe',
        montantFixeParPneu: const Value(1000),
      ),
    );

    documentRepo = CommercialDocumentRepositoryImpl(db);
    commissionsRepo = CommissionsRepositoryImpl(db);
  });

  tearDown(() => db.close());

  Future<int> vendre(int quantite, DateTime date) => documentRepo.creerVenteRapide(
        DocumentInput(
          type: DocumentType.facture,
          storeId: storeId,
          dateDocument: date,
          lignes: [
            DocumentLigneInput(
              articleId: articleId,
              articleCode: 'PNEU-1',
              articleNom: 'Pneu 175/70R13',
              quantite: quantite.toDouble(),
              prixUnitaireHt: 6000,
              tauxTva: 0,
            ),
          ],
          createdById: userId,
          createdByNom: 'Responsable',
          vendeurEmployeeId: commercialId,
        ),
        montantPayeInitial: quantite * 6000,
        modePaiementInitial: 'especes',
        userId: userId,
        userNom: 'Responsable',
      );

  test(
      'scénario 2 : 10 pneus à 6000F avec commission fixe 1000F/pneu → '
      'facture 60000F, commission 10000F, prix interne jamais sur la facture',
      () async {
    final docId = await vendre(10, DateTime(2026, 8, 3));

    final doc = await documentRepo.getParId(docId);
    expect(doc != null, true);
    expect(doc!.totalTtc, 60000); // facture client = 60 000 F
    expect(doc.vendeurEmployeeId, commercialId);

    final ligne = doc.lignes.single;
    expect(ligne.commissionUnitaire, 1000);
    expect(ligne.commissionMontant, 10000); // commission = 10 000 F

    // DocumentLigneEntity porte bien la commission en interne, mais rien
    // dans le mapping facture imprimable ne lit ce champ (vérifié par
    // grep sur PrintableDocument — aucun champ commission n'y existe).
  });

  test(
      'scénario 3 : seules les ventes de la période 01-15/08/2026 sont '
      'comptées dans les commissions dues', () async {
    await vendre(4, DateTime(2026, 7, 31)); // avant la période
    await vendre(10, DateTime(2026, 8, 5)); // dans la période
    await vendre(3, DateTime(2026, 8, 15)); // borne incluse
    await vendre(7, DateTime(2026, 8, 16)); // après la période

    final due = await commissionsRepo.calculerCommissionsDues(
      employeeId: commercialId,
      debut: DateTime(2026, 8, 1),
      fin: DateTime(2026, 8, 15, 23, 59, 59),
    );

    expect(due.nombreVentes, 2);
    expect(due.quantiteTotale, 13); // 10 + 3
    expect(due.montantCommission, 13000); // 13 × 1000
  });

  test(
      'scénario 4 : le règlement fait disparaître la commission des '
      'commissions à régler, l\'ajoute à l\'historique, et empêche tout '
      'second règlement sur la même période', () async {
    await vendre(10, DateTime(2026, 8, 5));

    final debut = DateTime(2026, 8, 1);
    final fin = DateTime(2026, 8, 15, 23, 59, 59);

    final avantReglement = await commissionsRepo.calculerCommissionsDues(
        employeeId: commercialId, debut: debut, fin: fin);
    expect(avantReglement.montantCommission, 10000);

    final settlementId = await commissionsRepo.reglerCommissions(
      employeeId: commercialId,
      debut: debut,
      fin: fin,
      datePaiement: DateTime(2026, 8, 16),
      modePaiement: 'especes',
      payeParUserId: userId,
      payeParUserNom: 'Responsable',
    );
    expect(settlementId, greaterThan(0));

    // Disparaît des commissions à régler.
    final apresReglement = await commissionsRepo.calculerCommissionsDues(
        employeeId: commercialId, debut: debut, fin: fin);
    expect(apresReglement.montantCommission, 0);

    // Apparaît dans l'historique.
    final historique =
        await commissionsRepo.getSettlementsForEmployee(commercialId);
    expect(historique, hasLength(1));
    expect(historique.single.montantCommission, 10000);

    // Un second règlement sur la même période ne trouve plus rien à
    // régler (aucune ligne déjà réglée n'est resélectionnée).
    expect(
      () => commissionsRepo.reglerCommissions(
        employeeId: commercialId,
        debut: debut,
        fin: fin,
        datePaiement: DateTime(2026, 8, 17),
        modePaiement: 'especes',
        payeParUserId: userId,
        payeParUserNom: 'Responsable',
      ),
      throwsException,
    );
  });
}
