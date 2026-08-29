import 'package:drift/drift.dart';
import '../local/database.dart';
import 'article_repository_impl.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/repositories/promotions_repository.dart';

class PromotionsRepositoryImpl implements PromotionsRepository {
  final AppDatabase db;

  PromotionsRepositoryImpl(this.db);

  Future<PromotionEntity> _toEntity(Promotion p, {bool avecArticles = true}) async {
    var articleIds = <int>[];
    var libelles = <String>[];
    if (avecArticles) {
      final articles = await db.promotionsDao.getArticlesForPromotion(p.id);
      articleIds = articles.map((a) => a.id).toList();
      libelles = articles.map((a) => '${a.code} — ${a.nom}').toList();
    }
    return PromotionEntity(
      id: p.id,
      nom: p.nom,
      type: PromotionType.fromDb(p.typeRemise),
      valeur: p.valeur,
      dateDebut: p.dateDebut,
      dateFin: p.dateFin,
      actif: p.actif,
      dateCreation: p.dateCreation,
      articleIds: articleIds,
      articlesLibelles: libelles,
    );
  }

  @override
  Future<List<PromotionEntity>> getAllPromotions() async {
    final rows = await db.promotionsDao.getAllPromotions();
    return Future.wait(rows.map((r) => _toEntity(r)));
  }

  @override
  Future<PromotionEntity?> getPromotionById(int id) async {
    final row = await db.promotionsDao.getPromotionById(id);
    if (row == null) return null;
    return _toEntity(row);
  }

  @override
  Future<int> createPromotion({
    required String nom,
    required PromotionType type,
    required double valeur,
    required DateTime dateDebut,
    required DateTime dateFin,
    bool actif = true,
    required List<int> articleIds,
  }) async {
    final id = await db.promotionsDao.createPromotion(
      PromotionsCompanion.insert(
        nom: nom,
        typeRemise: Value(type.toDb()),
        valeur: valeur,
        dateDebut: dateDebut,
        dateFin: dateFin,
        actif: Value(actif),
      ),
    );
    await db.promotionsDao.setArticlesForPromotion(id, articleIds);
    return id;
  }

  @override
  Future<void> updatePromotion({
    required int id,
    required String nom,
    required PromotionType type,
    required double valeur,
    required DateTime dateDebut,
    required DateTime dateFin,
    required bool actif,
    required List<int> articleIds,
  }) async {
    final existant = await db.promotionsDao.getPromotionById(id);
    if (existant == null) return;
    await db.promotionsDao.updatePromotion(existant.copyWith(
      nom: nom,
      typeRemise: type.toDb(),
      valeur: valeur,
      dateDebut: dateDebut,
      dateFin: dateFin,
      actif: actif,
    ));
    await db.promotionsDao.setArticlesForPromotion(id, articleIds);
  }

  @override
  Future<void> deletePromotion(int id) => db.promotionsDao.deletePromotion(id);

  @override
  Future<Map<int, PromotionEntity>> getActivePromotionsMap() async {
    final rows = await db.promotionsDao.getActivePromotionsMap(DateTime.now());
    final result = <int, PromotionEntity>{};
    for (final entry in rows.entries) {
      result[entry.key] = await _toEntity(entry.value, avecArticles: false);
    }
    return result;
  }

  @override
  Future<PromotionPerformanceEntity> getPerformance(int promotionId) async {
    final lignes =
        await db.promotionsDao.getLignesVenduesPourPromotion(promotionId);
    if (lignes.isEmpty) {
      return PromotionPerformanceEntity(
        promotionId: promotionId,
        quantiteVendue: 0,
        nombreVentes: 0,
        chiffreAffaires: 0,
        remiseAccordee: 0,
        margeNormaleEstimee: 0,
        margeReelle: 0,
      );
    }

    final articleRepo = ArticleRepositoryImpl(db);
    final coutParArticle = <int, double>{};
    final documentIds = <int>{};
    double quantiteVendue = 0;
    double chiffreAffaires = 0;
    double remiseAccordee = 0;
    double margeNormaleEstimee = 0;

    for (final l in lignes) {
      documentIds.add(l.documentId);
      quantiteVendue += l.quantite;
      chiffreAffaires += l.totalHt;
      remiseAccordee += l.quantite * l.prixUnitaireHt * l.remiseLignePct / 100;

      var cout = coutParArticle[l.articleId];
      if (cout == null) {
        final article = await articleRepo.getArticleById(l.articleId);
        cout = article?.prixRevient ?? article?.prixAchat ?? 0;
        coutParArticle[l.articleId] = cout;
      }
      margeNormaleEstimee += l.quantite * (l.prixUnitaireHt - cout);
    }

    return PromotionPerformanceEntity(
      promotionId: promotionId,
      quantiteVendue: quantiteVendue,
      nombreVentes: documentIds.length,
      chiffreAffaires: chiffreAffaires,
      remiseAccordee: remiseAccordee,
      margeNormaleEstimee: margeNormaleEstimee,
      margeReelle: margeNormaleEstimee - remiseAccordee,
    );
  }
}
