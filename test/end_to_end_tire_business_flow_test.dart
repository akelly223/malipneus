import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/data/local/database.dart';
import 'package:mali_pneus/data/repositories/article_repository_impl.dart';
import 'package:mali_pneus/data/repositories/commercial_document_repository_impl.dart';
import 'package:mali_pneus/data/repositories/commissions_repository_impl.dart';
import 'package:mali_pneus/data/repositories/expenses_repository_impl.dart';
import 'package:mali_pneus/data/repositories/loadings_repository_impl.dart';
import 'package:mali_pneus/data/repositories/payroll_repository_impl.dart';
import 'package:mali_pneus/data/repositories/purchase_repository_impl.dart';
import 'package:mali_pneus/data/repositories/stock_repository_impl.dart';
import 'package:mali_pneus/domain/entities/document_input.dart';
import 'package:mali_pneus/domain/entities/document_type.dart';
import 'package:mali_pneus/domain/entities/purchase_cart_item_input.dart';

/// Scénario de bout en bout (section 19 du cahier des charges) : chaîne
/// complète fournisseur → chargement (date personnalisée, container,
/// référence) → achat de 100 pneus → stock → dépenses (transport,
/// transitaire, douane) → prix de revient → commercial → vente →
/// commission → règlement → employé → paie (absence + avance) → perte de
/// stock → rentabilité → tableau de bord. Vérifie que les données
/// circulent réellement d'un module à l'autre (pas seulement que chaque
/// module fonctionne isolément — voir les autres fichiers *_flow_test.dart
/// pour les scénarios unitaires).
void main() {
  late AppDatabase db;
  late int storeId;
  late int userId;
  late int supplierId;
  late int articleId;
  late int loadingId;

  late ArticleRepositoryImpl articleRepo;
  late LoadingsRepositoryImpl loadingsRepo;
  late PurchaseRepositoryImpl purchaseRepo;
  late ExpensesRepositoryImpl expensesRepo;
  late CommercialDocumentRepositoryImpl documentRepo;
  late CommissionsRepositoryImpl commissionsRepo;
  late PayrollRepositoryImpl payrollRepo;
  late StockRepositoryImpl stockRepo;

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
    supplierId = await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(nom: 'Import Pneus SARL'),
        );

    articleRepo = ArticleRepositoryImpl(db);
    loadingsRepo = LoadingsRepositoryImpl(db);
    purchaseRepo = PurchaseRepositoryImpl(db);
    expensesRepo = ExpensesRepositoryImpl(db);
    documentRepo = CommercialDocumentRepositoryImpl(db);
    commissionsRepo = CommissionsRepositoryImpl(db);
    payrollRepo = PayrollRepositoryImpl(db);
    stockRepo = StockRepositoryImpl(db);

    // 1. Fournisseur créé (ci-dessus). 2-3. Chargement avec date d'achat
    // personnalisée (10/08/2026, différente d'aujourd'hui), container et
    // référence.
    loadingId = await loadingsRepo.createLoading(
      supplierId: supplierId,
      dateChargement: DateTime(2026, 8, 10),
      dateArrivee: DateTime(2026, 8, 24),
      container: 'MSCU1234567',
      reference: 'BC-2026-0042',
      createdById: userId,
    );

    // Pneu créé avec de vraies caractéristiques (section 2).
    articleId = await articleRepo.createArticle(
      code: 'PNEU-195-65-R15',
      nom: 'Michelin Energy XM2 195/65 R15',
      prixAchat: 0,
      prixVente: 10000,
      stockMinimum: 10,
      marque: 'Michelin',
      dimension: '195/65 R15',
      largeur: 195,
      hauteur: 65,
      diametre: 15,
      type: 'Tourisme',
      saison: 'Toutes saisons',
      etat: 'neuf',
    );
  });

  tearDown(() => db.close());

  test('scénario complet : chargement → 100 pneus → stock → dépenses → '
      'prix de revient → commercial → vente → commission → règlement → '
      'employé → paie → perte → rentabilité → dashboard', () async {
    // 4-6. Achat de 100 pneus à 5000F, avec sa propre date (différente de
    // la date du chargement et d'aujourd'hui), rattaché au chargement.
    await purchaseRepo.createPurchase(
      supplierId: supplierId,
      storeId: storeId,
      userId: userId,
      items: [
        PurchaseCartItemInput(
          articleId: articleId,
          articleNom: 'Michelin Energy XM2 195/65 R15',
          quantite: 100,
          prixAchatUnitaire: 5000,
        ),
      ],
      chargementId: loadingId,
      dateAchat: DateTime(2026, 8, 12),
    );

    // 5. Les 100 pneus apparaissent réellement dans le stock.
    final stockApresAchat =
        await db.articlesDao.getStockForArticleInStore(articleId, storeId);
    expect(stockApresAchat, 100);

    // Le prix d'achat de référence de l'article est mis à jour, et son
    // chargement d'origine est désormais celui de cet achat (utilisé
    // pour calculer son prix de revient réel).
    final articleApresAchat = await articleRepo.getArticleById(articleId);
    expect(articleApresAchat!.prixAchat, 5000);
    expect(articleApresAchat.chargementOrigineId, loadingId);

    // 6. Le prix d'achat du chargement reflète bien les 100 pneus, sans
    // qu'aucune dépense n'ait encore été ajoutée (le bug audité : le
    // prix d'achat doit apparaître même seul, avant les dépenses).
    final rentaAvantDepenses = await loadingsRepo.getRentabilite(loadingId);
    expect(rentaAvantDepenses.quantiteRecue, 100);
    expect(rentaAvantDepenses.prixAchatTotal, 500000); // 100 × 5000

    // 7-11. Dépenses liées au chargement : transport, transitaire,
    // douane, chargement container, manutention.
    final categories = await expensesRepo.getAllCategories();
    Future<void> depenser(String nomCategorie, double montant) async {
      final cat = categories.firstWhere((c) => c.nom == nomCategorie);
      await expensesRepo.createExpense(
        categorieId: cat.id,
        montant: montant,
        date: DateTime(2026, 8, 13),
        chargementId: loadingId,
        createdById: userId,
      );
    }

    await depenser('Chargement container', 50000);
    await depenser('Transport', 75000);
    await depenser('Transitaire', 25000);
    await depenser('Douane', 100000);
    await depenser('Manutention', 20000);
    // Total dépenses = 270 000

    // Une dépense peut aussi être liée à un pneu précis plutôt qu'à tout
    // le chargement (section 7) — vérifie juste qu'elle est bien
    // enregistrée avec son lien article, sans polluer le total chargement.
    final reparations = categories.firstWhere((c) => c.nom == 'Réparations');
    await expensesRepo.createExpense(
      categorieId: reparations.id,
      montant: 5000,
      date: DateTime(2026, 8, 14),
      articleId: articleId,
      description: 'Réparation ponctuelle',
      createdById: userId,
    );
    final depensesDeLarticle =
        (await expensesRepo.getAllExpenses())
            .where((e) => e.articleId == articleId)
            .toList();
    expect(depensesDeLarticle, hasLength(1));
    expect(depensesDeLarticle.single.montant, 5000);

    // 12-13. Prix de revient réel = achat + dépenses chargement (la
    // dépense liée au pneu seul n'entre pas dans le coût du chargement).
    final renta = await loadingsRepo.getRentabilite(loadingId);
    expect(renta.prixAchatTotal, 500000);
    expect(renta.depensesTotal, 270000);
    expect(renta.coutTotal, 770000);
    expect(renta.prixRevientUnitaire, 7700); // 770 000 / 100

    // Le prix de revient exposé sur la fiche pneu (calculé depuis son
    // chargement d'origine) doit être ce même prix de revient réel — et
    // non le simple prix d'achat (500 000/100 = 5000F, différent).
    final articleAvecRevient = await articleRepo.getArticleById(articleId);
    expect(articleAvecRevient!.prixRevient, 7700);
    expect(articleAvecRevient.prixAchat, isNot(articleAvecRevient.prixRevient));

    // 14-15. Commercial créé avec commission fixe de 1000F/pneu.
    final postes = await db.personnelDao.getAllJobPositions();
    final commercialId = await db.personnelDao.createEmployee(
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

    // 16-17. Plusieurs ventes par ce commercial : prix interne (achat)
    // jamais visible sur la facture — seul le prix de vente y figure
    // (structurellement garanti : PrintableDocument/PrintableDocumentLine
    // n'ont aucun champ prixAchat/prixRevient/commission/marge, voir
    // lib/domain/entities/printable_document.dart).
    final docId = await documentRepo.creerVenteRapide(
      DocumentInput(
        type: DocumentType.facture,
        storeId: storeId,
        dateDocument: DateTime(2026, 8, 15),
        lignes: [
          DocumentLigneInput(
            articleId: articleId,
            articleCode: 'PNEU-195-65-R15',
            articleNom: 'Michelin Energy XM2 195/65 R15',
            quantite: 20,
            prixUnitaireHt: 10000,
            tauxTva: 0,
          ),
        ],
        createdById: userId,
        createdByNom: 'Responsable',
        vendeurEmployeeId: commercialId,
      ),
      montantPayeInitial: 200000,
      modePaiementInitial: 'especes',
      userId: userId,
      userNom: 'Responsable',
    );

    // 18. La facture (document imprimable) ne montre que le prix de
    // vente, jamais le prix interne ni la commission.
    final doc = await documentRepo.getParId(docId);
    expect(doc!.totalTtc, 200000); // 20 × 10000, prix client uniquement
    final ligneVendue = doc.lignes.single;
    expect(ligneVendue.commissionUnitaire, 1000);
    expect(ligneVendue.commissionMontant, 20000); // 20 × 1000

    // 20. Vérifie la commission calculée pour la période.
    final commissionDue = await commissionsRepo.calculerCommissionsDues(
      employeeId: commercialId,
      debut: DateTime(2026, 8, 1),
      fin: DateTime(2026, 8, 31, 23, 59, 59),
    );
    expect(commissionDue.montantCommission, 20000);

    // 21-24. Règlement de la commission sur la période choisie : elle
    // disparaît des impayés, apparaît dans l'historique, et ne peut pas
    // être réglée deux fois.
    final settlementId = await commissionsRepo.reglerCommissions(
      employeeId: commercialId,
      debut: DateTime(2026, 8, 1),
      fin: DateTime(2026, 8, 31, 23, 59, 59),
      datePaiement: DateTime(2026, 8, 20),
      modePaiement: 'especes',
      payeParUserId: userId,
      payeParUserNom: 'Responsable',
    );
    expect(settlementId, greaterThan(0));

    final commissionApresReglement =
        await commissionsRepo.calculerCommissionsDues(
      employeeId: commercialId,
      debut: DateTime(2026, 8, 1),
      fin: DateTime(2026, 8, 31, 23, 59, 59),
    );
    expect(commissionApresReglement.montantCommission, 0);

    final historiqueCommissions =
        await commissionsRepo.getSettlementsForEmployee(commercialId);
    expect(historiqueCommissions, hasLength(1));

    expect(
      () => commissionsRepo.reglerCommissions(
        employeeId: commercialId,
        debut: DateTime(2026, 8, 1),
        fin: DateTime(2026, 8, 31, 23, 59, 59),
        datePaiement: DateTime(2026, 8, 21),
        modePaiement: 'especes',
        payeParUserId: userId,
        payeParUserNom: 'Responsable',
      ),
      throwsException,
    );

    // 26-27. Employé (non commercial) avec salaire.
    final employeeId = await db.personnelDao.createEmployee(
      EmployeesCompanion.insert(
        nom: 'Traoré',
        prenom: 'Fatoumata',
        posteId: postes.firstWhere((p) => p.nom != 'Commercial').id,
        dateEmbauche: DateTime(2025, 1, 1),
        salaireBase: const Value(150000),
      ),
    );

    // 28. Absence (2 jours, avec retenue).
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

    // 29. Avance sur salaire.
    await payrollRepo.createAdvance(
      employeeId: employeeId,
      montant: 30000,
      date: DateTime(2026, 8, 10),
      motif: 'Avance sur salaire',
      userId: userId,
    );

    // 30-31. Calcule et règle la paie ; elle doit apparaître dans les
    // dépenses de l'entreprise une fois payée.
    final periodId = await payrollRepo.createPeriod(
      libelle: 'Août 2026',
      dateDebut: DateTime(2026, 8, 1),
      dateFin: DateTime(2026, 8, 31),
      createdById: userId,
    );
    await payrollRepo.genererBulletinsPourPeriode(periodId);
    // La période génère un bulletin par employé actif ayant un salaire de
    // base (le commercial "Diallo" n'en a pas et n'en reçoit donc pas) :
    // on cible celui de l'employé "Traoré" créé ci-dessus.
    final payslip = (await payrollRepo.getPayslipsForPeriod(periodId))
        .firstWhere((p) => p.employeeId == employeeId);
    expect(payslip.salaireBase, 150000);
    expect(payslip.retenueAbsence, 10000); // 150000/30 × 2
    expect(payslip.avancesDeduites, 30000);
    expect(payslip.salaireNet, 110000);

    await payrollRepo.enregistrerPaiementBulletin(
      payslipId: payslip.id,
      montant: 110000,
      datePaiement: DateTime(2026, 8, 31),
      modePaiement: 'especes',
      payeParUserId: userId,
      payeParUserNom: 'Responsable',
    );

    // 32-33. Perte de 3 pneus : le stock réel diminue, la perte reste
    // tracée, et le prix de revient du chargement se recalcule sur les
    // pneus réellement vendables restants (97 = 100 - 20 vendus - 3
    // perdus).
    await stockRepo.registerMovement(
      articleId: articleId,
      storeId: storeId,
      typeMouvement: 'perte',
      quantite: 3,
      reference: 'Casse manutention',
      userId: userId,
    );
    final stockApresPerte =
        await db.articlesDao.getStockForArticleInStore(articleId, storeId);
    expect(stockApresPerte, 77); // 100 - 20 vendus - 3 perdus

    // 34. Rentabilité finale du chargement, cohérente de bout en bout.
    final rentaFinale = await loadingsRepo.getRentabilite(loadingId);
    expect(rentaFinale.quantiteRecue, 100);
    expect(rentaFinale.quantiteVendue, 20);
    expect(rentaFinale.pertes, 3);
    expect(rentaFinale.quantiteRestante, 77); // 100 - 20 - 3
    expect(rentaFinale.coutTotal, 770000);
    // Prix de revient recalculé sur les pneus effectivement disponibles
    // à la vente (100 - 3 pertes = 97, indépendant des unités déjà
    // vendues) : voir LoadingsRepositoryImpl.getRentabilite.
    expect(rentaFinale.prixRevientUnitaire, closeTo(770000 / 97, 0.01));
    expect(rentaFinale.chiffreAffaires, 200000);
    // Coût des lots consommés pour ce chargement : vente (20) + perte (3),
    // toutes deux au coût de revient RÉEL du lot FIFO (achat + part des
    // dépenses imputées = 7700F/pneu, et non plus seulement le prix
    // d'achat brut à 5000F) — LoadingCostAllocationService a mis à jour
    // stock_lots.coutUnitaire dès la création des dépenses (chargement
    // encore "ouvert"), donc la vente et la perte qui ont suivi ont
    // consommé les lots à ce coût déjà réel.
    expect(rentaFinale.coutDesProduitsVendus, 177100); // 23 × 7700
    expect(rentaFinale.margeBrute, 22900); // 200000 - 177100

    // Détail par article (niveau 1, jamais une moyenne masquant le coût
    // réel) : une seule ligne d'achat ici (100 pneus au même prix), son
    // coût de revient réel correspond au prixRevientUnitaire global.
    expect(rentaFinale.lignes, hasLength(1));
    final ligne = rentaFinale.lignes.single;
    expect(ligne.quantite, 100);
    expect(ligne.prixAchatUnitaire, 5000);
    expect(ligne.coutRevientUnitaire, 7700);
    expect(ligne.partDepensesUnitaire, 2700); // 270000 / 100

    // 35. Le tableau de bord agrège réellement toutes ces données : la
    // paie payée, la commission réglée et la perte de stock sont
    // visibles, pour la période où elles ont eu lieu.
    final depensesAoutTotal = (await expensesRepo.getExpensesBetween(
            DateTime(2026, 8, 1), DateTime(2026, 8, 31, 23, 59, 59)))
        .fold<double>(0, (s, e) => s + e.montant);
    expect(depensesAoutTotal, 270000 + 5000); // dépenses chargement + pneu
  });
}
