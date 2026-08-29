import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/data/local/database.dart';
import 'package:mali_pneus/data/repositories/commercial_document_repository_impl.dart';
import 'package:mali_pneus/data/repositories/promotions_repository_impl.dart';
import 'package:mali_pneus/domain/entities/document_input.dart';
import 'package:mali_pneus/domain/entities/document_type.dart';
import 'package:mali_pneus/domain/entities/promotion.dart';

/// Le tableau de bord "performance d'une promotion" doit mesurer les
/// ventes RÉELLEMENT liées à une promotion (pas une estimation) : la
/// cliente veut voir combien de pneus vendus, quel chiffre d'affaires,
/// et surtout combien de marge la remise lui a coûté — pour savoir si
/// la promotion reste rentable.
void main() {
  late AppDatabase db;
  late int storeId;
  late int userId;
  late int articleId;
  late CommercialDocumentRepositoryImpl documentRepo;
  late PromotionsRepositoryImpl promotionsRepo;

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
            prixAchat: const Value(30000),
            prixVente: 50000,
          ),
        );
    await db.into(db.articleStocks).insert(
          ArticleStocksCompanion.insert(
            articleId: articleId,
            storeId: storeId,
            quantite: const Value(100),
          ),
        );

    documentRepo = CommercialDocumentRepositoryImpl(db);
    promotionsRepo = PromotionsRepositoryImpl(db);
  });

  tearDown(() => db.close());

  Future<int> vendre(double quantite, double remisePct, int? promotionId) =>
      documentRepo.creerVenteRapide(
        DocumentInput(
          type: DocumentType.facture,
          storeId: storeId,
          dateDocument: DateTime.now(),
          lignes: [
            DocumentLigneInput(
              articleId: articleId,
              articleCode: 'PNEU-1',
              articleNom: 'Pneu 175/70R13',
              quantite: quantite,
              prixUnitaireHt: 50000,
              tauxTva: 0,
              remiseLignePct: remisePct,
              promotionId: promotionId,
            ),
          ],
          createdById: userId,
          createdByNom: 'Responsable',
        ),
        montantPayeInitial: quantite * 50000 * (1 - remisePct / 100),
        modePaiementInitial: 'especes',
        userId: userId,
        userNom: 'Responsable',
      );

  test(
      '4 pneus vendus à -10% durant la promo : CA, remise accordée et '
      'marge perdue calculés sur le prix de vente réel (prix de revient '
      'indisponible ici → repli sur le prix d\'achat, 30000F)',
      () async {
    final promoId = await promotionsRepo.createPromotion(
      nom: 'Solde rentrée',
      type: PromotionType.pourcentage,
      valeur: 10,
      dateDebut: DateTime.now().subtract(const Duration(days: 1)),
      dateFin: DateTime.now().add(const Duration(days: 1)),
      articleIds: [articleId],
    );

    await vendre(4, 10, promoId);
    // Une vente hors promotion (remise manuelle, sans promotionId) ne
    // doit jamais être comptée dans la performance de la promo — même
    // si le pourcentage de remise coïncide.
    await vendre(2, 10, null);

    final perf = await promotionsRepo.getPerformance(promoId);

    expect(perf.nombreVentes, 1);
    expect(perf.quantiteVendue, 4);
    expect(perf.chiffreAffaires, 180000); // 4 × 50000 × 0.9
    expect(perf.remiseAccordee, 20000); // 4 × 50000 × 10%
    expect(perf.margeNormaleEstimee, 80000); // 4 × (50000 - 30000)
    expect(perf.margeReelle, 60000); // 80000 - 20000
    expect(perf.pourcentageMargePerdue, 25); // 20000 / 80000
  });

  test('une promotion sans aucune vente facturée a une performance à zéro',
      () async {
    final promoId = await promotionsRepo.createPromotion(
      nom: 'Jamais vendue',
      type: PromotionType.pourcentage,
      valeur: 15,
      dateDebut: DateTime.now().subtract(const Duration(days: 1)),
      dateFin: DateTime.now().add(const Duration(days: 1)),
      articleIds: [articleId],
    );

    final perf = await promotionsRepo.getPerformance(promoId);
    expect(perf.nombreVentes, 0);
    expect(perf.quantiteVendue, 0);
    expect(perf.chiffreAffaires, 0);
    expect(perf.remiseAccordee, 0);
    expect(perf.margeReelle, 0);
  });

  test('une vente annulée n\'est jamais comptée dans la performance',
      () async {
    final promoId = await promotionsRepo.createPromotion(
      nom: 'Solde annulée',
      type: PromotionType.pourcentage,
      valeur: 10,
      dateDebut: DateTime.now().subtract(const Duration(days: 1)),
      dateFin: DateTime.now().add(const Duration(days: 1)),
      articleIds: [articleId],
    );
    final docId = await vendre(3, 10, promoId);
    await db.commercialDocumentsDao.mettreAJourStatut(docId, 'annule');

    final perf = await promotionsRepo.getPerformance(promoId);
    expect(perf.nombreVentes, 0);
    expect(perf.quantiteVendue, 0);
  });
}
