import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/promotions_table.dart';
import '../tables/articles_table.dart';
import '../tables/document_lines_table.dart';
import '../tables/commercial_documents_table.dart';

part 'promotions_dao.g.dart';

/// Types de document comptant comme une vente réalisée (voir la même
/// convention dans [DashboardRepositoryImpl] : seuls les documents
/// facturés et non annulés comptent, pour ne jamais compter deux fois
/// la même vente en additionnant aussi la chaîne proforma/BC/BL.
const _typesVenteRealisee = ['facture', 'facture_comptabilisee'];

@DriftAccessor(tables: [
  Promotions,
  PromotionArticles,
  Articles,
  DocumentLines,
  CommercialDocuments,
])
class PromotionsDao extends DatabaseAccessor<AppDatabase>
    with _$PromotionsDaoMixin {
  PromotionsDao(super.db);

  Future<List<Promotion>> getAllPromotions() =>
      (select(promotions)
            ..orderBy([(p) => OrderingTerm.desc(p.dateCreation)]))
          .get();

  Future<Promotion?> getPromotionById(int id) =>
      (select(promotions)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> createPromotion(PromotionsCompanion promotion) =>
      into(promotions).insert(promotion);

  Future<bool> updatePromotion(Promotion promotion) =>
      update(promotions).replace(promotion);

  Future<void> deletePromotion(int id) async {
    await (delete(promotionArticles)..where((pa) => pa.promotionId.equals(id)))
        .go();
    await (delete(promotions)..where((p) => p.id.equals(id))).go();
  }

  Future<List<int>> getArticleIdsForPromotion(int promotionId) async {
    final rows = await (select(promotionArticles)
          ..where((pa) => pa.promotionId.equals(promotionId)))
        .get();
    return rows.map((r) => r.articleId).toList();
  }

  /// Remplace entièrement la sélection de pneus d'une promotion.
  Future<void> setArticlesForPromotion(
      int promotionId, List<int> articleIds) async {
    await (delete(promotionArticles)
          ..where((pa) => pa.promotionId.equals(promotionId)))
        .go();
    for (final articleId in articleIds) {
      await into(promotionArticles).insert(
        PromotionArticlesCompanion.insert(
          promotionId: promotionId,
          articleId: articleId,
        ),
      );
    }
  }

  /// Pneus (id, code, nom) actuellement rattachés à une promotion —
  /// utilisé pour l'affichage dans la liste/le formulaire de gestion.
  Future<List<Article>> getArticlesForPromotion(int promotionId) async {
    final query = select(articles).join([
      innerJoin(
          promotionArticles, promotionArticles.articleId.equalsExp(articles.id)),
    ])
      ..where(promotionArticles.promotionId.equals(promotionId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(articles)).toList();
  }

  /// Promotions actives couvrant chaque pneu à l'instant [moment],
  /// indexées par articleId → promotion donnant le meilleur prix (utile
  /// quand plusieurs promotions actives se chevauchent sur un même
  /// pneu). Utilisé pour préremplir automatiquement le prix promo à la
  /// saisie d'une ligne de vente.
  Future<Map<int, Promotion>> getActivePromotionsMap(DateTime moment) async {
    final query = select(promotions).join([
      innerJoin(promotionArticles,
          promotionArticles.promotionId.equalsExp(promotions.id)),
      innerJoin(articles, articles.id.equalsExp(promotionArticles.articleId)),
    ])
      ..where(promotions.actif.equals(true))
      ..where(promotions.dateDebut.isSmallerOrEqualValue(moment))
      ..where(promotions.dateFin.isBiggerOrEqualValue(moment));
    final rows = await query.get();

    final meilleurPrix = <int, double>{};
    final result = <int, Promotion>{};
    for (final row in rows) {
      final articleId = row.readTable(promotionArticles).articleId;
      final promo = row.readTable(promotions);
      final article = row.readTable(articles);
      final prixCalcule = promo.typeRemise == 'pourcentage'
          ? article.prixVente * (1 - promo.valeur / 100)
          : article.prixVente - promo.valeur;
      final prix = prixCalcule < 0 ? 0.0 : prixCalcule;
      final actuel = meilleurPrix[articleId];
      if (actuel == null || prix < actuel) {
        meilleurPrix[articleId] = prix;
        result[articleId] = promo;
      }
    }
    return result;
  }

  /// Lignes de vente RÉELLEMENT liées à cette promotion (celles dont le
  /// prix a été préremplié par elle à la saisie — voir
  /// [DocumentLinesEditor]), restreintes aux documents effectivement
  /// facturés et non annulés — jamais une estimation après coup.
  Future<List<
      ({
        int articleId,
        int documentId,
        double quantite,
        double prixUnitaireHt,
        double remiseLignePct,
        double totalHt,
      })>> getLignesVenduesPourPromotion(int promotionId) async {
    final query = select(documentLines).join([
      innerJoin(commercialDocuments,
          commercialDocuments.id.equalsExp(documentLines.documentId)),
    ])
      ..where(documentLines.promotionId.equals(promotionId))
      ..where(commercialDocuments.type.isIn(_typesVenteRealisee))
      ..where(commercialDocuments.statut.equals('annule').not());
    final rows = await query.get();
    return rows.map((r) {
      final l = r.readTable(documentLines);
      return (
        articleId: l.articleId,
        documentId: l.documentId,
        quantite: l.quantite,
        prixUnitaireHt: l.prixUnitaireHt,
        remiseLignePct: l.remiseLignePct,
        totalHt: l.totalHt,
      );
    }).toList();
  }
}
