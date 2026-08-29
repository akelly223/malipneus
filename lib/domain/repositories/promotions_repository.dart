import '../entities/promotion.dart';

abstract class PromotionsRepository {
  Future<List<PromotionEntity>> getAllPromotions();

  Future<PromotionEntity?> getPromotionById(int id);

  Future<int> createPromotion({
    required String nom,
    required PromotionType type,
    required double valeur,
    required DateTime dateDebut,
    required DateTime dateFin,
    bool actif = true,
    required List<int> articleIds,
  });

  Future<void> updatePromotion({
    required int id,
    required String nom,
    required PromotionType type,
    required double valeur,
    required DateTime dateDebut,
    required DateTime dateFin,
    required bool actif,
    required List<int> articleIds,
  });

  Future<void> deletePromotion(int id);

  /// Promotions actives à l'instant présent, indexées par articleId —
  /// utilisé pour préremplir le prix promo à la saisie d'une vente.
  Future<Map<int, PromotionEntity>> getActivePromotionsMap();

  /// Performance réelle d'une promotion — mesurée sur les ventes
  /// effectivement enregistrées, jamais estimée après coup.
  Future<PromotionPerformanceEntity> getPerformance(int promotionId);
}
