import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/data/local/database.dart';
import 'package:mali_pneus/data/repositories/loadings_repository_impl.dart';
import 'package:mali_pneus/data/repositories/purchase_repository_impl.dart';
import 'package:mali_pneus/data/repositories/expenses_repository_impl.dart';
import 'package:mali_pneus/data/repositories/commercial_document_repository_impl.dart';
import 'package:mali_pneus/data/repositories/stock_repository_impl.dart';
import 'package:mali_pneus/domain/entities/purchase_cart_item_input.dart';
import 'package:mali_pneus/domain/entities/document_input.dart';
import 'package:mali_pneus/domain/entities/document_type.dart';

/// Scénarios 5 et 6 du cahier des charges : chargement de 500 pneus
/// avec achat + dépenses annexes, puis une perte de 5 pneus — le prix
/// de revient et la rentabilité doivent se recalculer correctement.
void main() {
  late AppDatabase db;
  late int storeId;
  late int supplierId;
  late int userId;
  late int articleId;
  late LoadingsRepositoryImpl loadingsRepo;
  late PurchaseRepositoryImpl purchaseRepo;
  late ExpensesRepositoryImpl expensesRepo;

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
          SuppliersCompanion.insert(nom: 'Fournisseur Chine'),
        );
    articleId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'PNEU-500',
            nom: 'Pneu conteneur',
            prixVente: 8000,
          ),
        );

    loadingsRepo = LoadingsRepositoryImpl(db);
    purchaseRepo = PurchaseRepositoryImpl(db);
    expensesRepo = ExpensesRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test(
      'scénario 5 : 500 pneus, achat 2 500 000F + dépenses 850 000F → '
      'prix de revient unitaire = 6700F', () async {
    final loadingId = await loadingsRepo.createLoading(
      supplierId: supplierId,
      dateChargement: DateTime(2026, 7, 1),
      createdById: userId,
    );

    await purchaseRepo.createPurchase(
      supplierId: supplierId,
      storeId: storeId,
      userId: userId,
      items: [
        PurchaseCartItemInput(
          articleId: articleId,
          articleNom: 'Pneu conteneur',
          quantite: 500,
          prixAchatUnitaire: 5000, // 500 × 5000 = 2 500 000
        ),
      ],
      chargementId: loadingId,
    );

    final categories = await expensesRepo.getAllCategories();
    Future<void> depenser(String nomCategorie, double montant) async {
      final cat = categories.firstWhere((c) => c.nom == nomCategorie);
      await expensesRepo.createExpense(
        categorieId: cat.id,
        montant: montant,
        date: DateTime(2026, 7, 2),
        chargementId: loadingId,
        createdById: userId,
      );
    }

    await depenser('Chargement container', 150000);
    await depenser('Transport', 200000);
    await depenser('Transitaire', 100000);
    await depenser('Douane', 350000);
    await depenser('Manutention', 50000);
    // Total dépenses = 850 000

    final renta = await loadingsRepo.getRentabilite(loadingId);
    expect(renta.quantiteRecue, 500);
    expect(renta.prixAchatTotal, 2500000);
    expect(renta.depensesTotal, 850000);
    expect(renta.coutTotal, 3350000);
    expect(renta.prixRevientUnitaire, 6700); // 3 350 000 / 500
  });

  test(
      'scénario 6 : une perte de 5 pneus recalcule le stock et le prix '
      'de revient sur les 495 restants', () async {
    final loadingId = await loadingsRepo.createLoading(
      supplierId: supplierId,
      dateChargement: DateTime(2026, 7, 1),
      createdById: userId,
    );

    await purchaseRepo.createPurchase(
      supplierId: supplierId,
      storeId: storeId,
      userId: userId,
      items: [
        PurchaseCartItemInput(
          articleId: articleId,
          articleNom: 'Pneu conteneur',
          quantite: 500,
          prixAchatUnitaire: 5000,
        ),
      ],
      chargementId: loadingId,
    );

    final categories = await expensesRepo.getAllCategories();
    final douane = categories.firstWhere((c) => c.nom == 'Douane');
    await expensesRepo.createExpense(
      categorieId: douane.id,
      montant: 850000,
      date: DateTime(2026, 7, 2),
      chargementId: loadingId,
      createdById: userId,
    );

    // Stock avant perte.
    final stockAvant = await db.articlesDao
        .getStockForArticleInStore(articleId, storeId);
    expect(stockAvant, 500);

    // Enregistre une perte de 5 pneus (module Pertes & ajustements,
    // construit sur StockRepositoryImpl.registerMovement existant).
    final stockRepo = StockRepositoryImpl(db);
    await stockRepo.registerMovement(
      articleId: articleId,
      storeId: storeId,
      typeMouvement: 'perte',
      quantite: 5,
      reference: 'Casse manutention',
      userId: userId,
    );

    // Le stock global (jamais supprimé silencieusement) reflète la perte.
    final stockApres = await db.articlesDao
        .getStockForArticleInStore(articleId, storeId);
    expect(stockApres, 495);

    // Le prix de revient est recalculé sur les 495 pneus réellement
    // disponibles : 3 350 000 / 495 ≈ 6767,68F.
    final renta = await loadingsRepo.getRentabilite(loadingId);
    expect(renta.pertes, 5);
    expect(renta.quantiteRestante, 495);
    expect(renta.prixRevientUnitaire, closeTo(3350000 / 495, 0.01));

    // La perte reste tracée dans stock_movements (jamais de suppression
    // silencieuse).
    final mouvements = await db.stockDao.getMovementsForArticle(articleId);
    expect(mouvements.any((m) => m.typeMouvement == 'perte'), true);
  });

  test('la vente d\'un article de ce chargement alimente sa rentabilité',
      () async {
    final loadingId = await loadingsRepo.createLoading(
      supplierId: supplierId,
      dateChargement: DateTime(2026, 7, 1),
      createdById: userId,
    );
    await purchaseRepo.createPurchase(
      supplierId: supplierId,
      storeId: storeId,
      userId: userId,
      items: [
        PurchaseCartItemInput(
          articleId: articleId,
          articleNom: 'Pneu conteneur',
          quantite: 500,
          prixAchatUnitaire: 5000,
        ),
      ],
      chargementId: loadingId,
    );

    final documentRepo = CommercialDocumentRepositoryImpl(db);
    await documentRepo.creerVenteRapide(
      DocumentInput(
        type: DocumentType.facture,
        storeId: storeId,
        dateDocument: DateTime(2026, 7, 10),
        lignes: [
          DocumentLigneInput(
            articleId: articleId,
            articleCode: 'PNEU-500',
            articleNom: 'Pneu conteneur',
            quantite: 10,
            prixUnitaireHt: 8000,
            tauxTva: 0,
          ),
        ],
        createdById: userId,
        createdByNom: 'Responsable',
      ),
      montantPayeInitial: 80000,
      modePaiementInitial: 'especes',
      userId: userId,
      userNom: 'Responsable',
    );

    final renta = await loadingsRepo.getRentabilite(loadingId);
    expect(renta.quantiteVendue, 10);
    expect(renta.chiffreAffaires, 80000);
    expect(renta.coutDesProduitsVendus, 50000); // 10 × 5000 (coût du lot)
    expect(renta.margeBrute, 30000); // 80000 - 50000
  });

  test(
      'coût de revient RÉEL par article (jamais une moyenne globale) : '
      '3 articles à des prix d\'achat différents dans le même chargement',
      () async {
    // Exemple exact du cahier des charges : 100 articles à 6000F,
    // 100 à 8000F, 100 à 13000F, + dépenses partagées Transport
    // 150000 + Douane 300000 + Transitaire 100000 = 550000.
    final articleA = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
              code: 'ART-A', nom: 'Article A', prixVente: 9000),
        );
    final articleB = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
              code: 'ART-B', nom: 'Article B', prixVente: 12000),
        );
    final articleC = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
              code: 'ART-C', nom: 'Article C', prixVente: 19000),
        );

    final loadingId = await loadingsRepo.createLoading(
      nom: 'Chargement AWA',
      supplierId: supplierId,
      dateChargement: DateTime(2026, 8, 1),
      createdById: userId,
    );

    await purchaseRepo.createPurchase(
      supplierId: supplierId,
      storeId: storeId,
      userId: userId,
      items: [
        PurchaseCartItemInput(
            articleId: articleA,
            articleNom: 'Article A',
            quantite: 100,
            prixAchatUnitaire: 6000),
        PurchaseCartItemInput(
            articleId: articleB,
            articleNom: 'Article B',
            quantite: 100,
            prixAchatUnitaire: 8000),
        PurchaseCartItemInput(
            articleId: articleC,
            articleNom: 'Article C',
            quantite: 100,
            prixAchatUnitaire: 13000),
      ],
      chargementId: loadingId,
    );

    final categories = await expensesRepo.getAllCategories();
    Future<void> depenser(String nomCategorie, double montant) async {
      final cat = categories.firstWhere((c) => c.nom == nomCategorie);
      await expensesRepo.createExpense(
        categorieId: cat.id,
        montant: montant,
        date: DateTime(2026, 8, 2),
        chargementId: loadingId,
        createdById: userId,
        methodeAllocation: 'quantite',
      );
    }

    await depenser('Transport', 150000);
    await depenser('Douane', 300000);
    await depenser('Transitaire', 100000);
    // Total dépenses partagées = 550 000, réparties également par
    // quantité (300 unités) = 1833,33F/unité.

    final renta = await loadingsRepo.getRentabilite(loadingId);

    // Niveau 2 (global) : la moyenne reste disponible en indicateur
    // secondaire, mais ne doit JAMAIS remplacer le détail par article.
    expect(renta.prixAchatTotal, 2700000); // 600000+800000+1300000
    expect(renta.depensesTotal, 550000);
    expect(renta.coutTotal, 3250000);

    // Niveau 1 (détail) : chaque article garde son propre coût réel —
    // PAS 3250000/300 = 10833,33F pour tout le monde.
    expect(renta.lignes, hasLength(3));
    final ligneA = renta.lignes.firstWhere((l) => l.articleId == articleA);
    final ligneB = renta.lignes.firstWhere((l) => l.articleId == articleB);
    final ligneC = renta.lignes.firstWhere((l) => l.articleId == articleC);

    const partPartagee = 550000 / 300; // 1833,333...

    expect(ligneA.prixAchatUnitaire, 6000);
    expect(ligneA.partDepensesUnitaire, closeTo(partPartagee, 0.01));
    expect(ligneA.coutRevientUnitaire, closeTo(6000 + partPartagee, 0.01));

    expect(ligneB.prixAchatUnitaire, 8000);
    expect(ligneB.coutRevientUnitaire, closeTo(8000 + partPartagee, 0.01));

    expect(ligneC.prixAchatUnitaire, 13000);
    expect(ligneC.coutRevientUnitaire, closeTo(13000 + partPartagee, 0.01));

    // Les 3 coûts de revient sont bien distincts (jamais une moyenne
    // unique appliquée à tous).
    expect(ligneA.coutRevientUnitaire, isNot(ligneB.coutRevientUnitaire));
    expect(ligneB.coutRevientUnitaire, isNot(ligneC.coutRevientUnitaire));

    // Marge/bénéfice par article, jamais une moyenne globale.
    expect(ligneA.margeUnitaire, closeTo(9000 - (6000 + partPartagee), 0.01));
    expect(ligneA.margeTotale, closeTo(ligneA.margeUnitaire * 100, 0.5));
  });

  test('le nom du chargement est éditable et affiché', () async {
    final loadingId = await loadingsRepo.createLoading(
      nom: 'Chargement Bamako',
      supplierId: supplierId,
      dateChargement: DateTime(2026, 8, 1),
      createdById: userId,
    );
    final loading = await loadingsRepo.getLoadingById(loadingId);
    expect(loading!.nom, 'Chargement Bamako');
    expect(loading.nomAffiche, 'Chargement Bamako');

    await loadingsRepo.updateLoading(
      id: loadingId,
      nom: 'Chargement Bamako (renommé)',
      dateChargement: loading.dateChargement,
    );
    final renomme = await loadingsRepo.getLoadingById(loadingId);
    expect(renomme!.nom, 'Chargement Bamako (renommé)');
  });
}
