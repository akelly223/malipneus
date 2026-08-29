import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/data/local/database.dart';
import 'package:mali_pneus/data/repositories/promotions_repository_impl.dart';
import 'package:mali_pneus/domain/entities/promotion.dart';

/// Promotion commerciale : remise (pourcentage ou montant fixe)
/// appliquée automatiquement sur un ou plusieurs pneus pendant une
/// période donnée. Vérifie la fenêtre de validité (dates + interrupteur
/// actif), le calcul du prix résultant pour les deux types de remise,
/// et l'intégration au flux de vente via [DocumentLinesEditor] (remise
/// équivalente en % appliquée à la ligne).
void main() {
  late AppDatabase db;
  late int articlePneu1Id;
  late int articlePneu2Id;
  late PromotionsRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    articlePneu1Id = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'PNEU-1',
            nom: 'Pneu 195/65 R15',
            prixVente: 50000,
          ),
        );
    articlePneu2Id = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            code: 'PNEU-2',
            nom: 'Pneu 205/55 R16',
            prixVente: 60000,
          ),
        );
    repo = PromotionsRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('une promotion en pourcentage, active aujourd\'hui, couvre bien '
      'plusieurs pneus et calcule le bon prix promo', () async {
    final now = DateTime.now();
    final id = await repo.createPromotion(
      nom: 'Solde rentrée',
      type: PromotionType.pourcentage,
      valeur: 10,
      dateDebut: now.subtract(const Duration(days: 1)),
      dateFin: now.add(const Duration(days: 1)),
      articleIds: [articlePneu1Id, articlePneu2Id],
    );

    final promo = await repo.getPromotionById(id);
    expect(promo, isNotNull);
    expect(promo!.articleIds, containsAll([articlePneu1Id, articlePneu2Id]));
    expect(promo.estEnCours, isTrue);
    expect(promo.statut, PromotionStatut.active);
    expect(promo.prixPromo(50000), 45000);
    expect(promo.remisePourcentageDe(50000), 10);

    final actives = await repo.getActivePromotionsMap();
    expect(actives[articlePneu1Id]?.id, id);
    expect(actives[articlePneu2Id]?.id, id);
  });

  test('une promotion en montant fixe se convertit correctement en % '
      'pour préremplir la remise de ligne de vente', () async {
    final now = DateTime.now();
    await repo.createPromotion(
      nom: 'Remise container',
      type: PromotionType.montant,
      valeur: 5000,
      dateDebut: now.subtract(const Duration(days: 1)),
      dateFin: now.add(const Duration(days: 1)),
      articleIds: [articlePneu1Id],
    );

    final actives = await repo.getActivePromotionsMap();
    final promo = actives[articlePneu1Id]!;
    expect(promo.prixPromo(50000), 45000);
    // 5000 / 50000 * 100 = 10%
    expect(promo.remisePourcentageDe(50000), 10);
  });

  test('une promotion planifiée dans le futur ou expirée n\'est jamais '
      'active, une promotion désactivée manuellement non plus', () async {
    final now = DateTime.now();

    await repo.createPromotion(
      nom: 'Future',
      type: PromotionType.pourcentage,
      valeur: 20,
      dateDebut: now.add(const Duration(days: 5)),
      dateFin: now.add(const Duration(days: 10)),
      articleIds: [articlePneu1Id],
    );
    await repo.createPromotion(
      nom: 'Expirée',
      type: PromotionType.pourcentage,
      valeur: 20,
      dateDebut: now.subtract(const Duration(days: 10)),
      dateFin: now.subtract(const Duration(days: 5)),
      articleIds: [articlePneu1Id],
    );
    await repo.createPromotion(
      nom: 'Désactivée',
      type: PromotionType.pourcentage,
      valeur: 20,
      dateDebut: now.subtract(const Duration(days: 1)),
      dateFin: now.add(const Duration(days: 1)),
      actif: false,
      articleIds: [articlePneu1Id],
    );

    final actives = await repo.getActivePromotionsMap();
    expect(actives.containsKey(articlePneu1Id), isFalse);
  });

  test('quand deux promotions actives couvrent le même pneu, le prix le '
      'plus avantageux pour le client est retenu', () async {
    final now = DateTime.now();
    final periode = (
      debut: now.subtract(const Duration(days: 1)),
      fin: now.add(const Duration(days: 1)),
    );

    await repo.createPromotion(
      nom: 'Petite remise',
      type: PromotionType.pourcentage,
      valeur: 5,
      dateDebut: periode.debut,
      dateFin: periode.fin,
      articleIds: [articlePneu1Id],
    );
    final grosseRemiseId = await repo.createPromotion(
      nom: 'Grosse remise',
      type: PromotionType.pourcentage,
      valeur: 30,
      dateDebut: periode.debut,
      dateFin: periode.fin,
      articleIds: [articlePneu1Id],
    );

    final actives = await repo.getActivePromotionsMap();
    expect(actives[articlePneu1Id]?.id, grosseRemiseId);
  });

  test('modifier une promotion remplace entièrement sa sélection de '
      'pneus, et la supprimer retire son effet', () async {
    final now = DateTime.now();
    final id = await repo.createPromotion(
      nom: 'Solde',
      type: PromotionType.pourcentage,
      valeur: 15,
      dateDebut: now.subtract(const Duration(days: 1)),
      dateFin: now.add(const Duration(days: 1)),
      articleIds: [articlePneu1Id],
    );

    await repo.updatePromotion(
      id: id,
      nom: 'Solde étendu',
      type: PromotionType.pourcentage,
      valeur: 15,
      dateDebut: now.subtract(const Duration(days: 1)),
      dateFin: now.add(const Duration(days: 1)),
      actif: true,
      articleIds: [articlePneu2Id],
    );

    var promo = await repo.getPromotionById(id);
    expect(promo!.articleIds, [articlePneu2Id]);
    expect(promo.nom, 'Solde étendu');

    await repo.deletePromotion(id);
    promo = await repo.getPromotionById(id);
    expect(promo, isNull);

    final actives = await repo.getActivePromotionsMap();
    expect(actives, isEmpty);
  });
}
