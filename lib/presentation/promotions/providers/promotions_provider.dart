import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/promotion.dart';

final promotionsListProvider =
    FutureProvider.autoDispose<List<PromotionEntity>>((ref) async {
  final repo = ref.watch(promotionsRepositoryProvider);
  return repo.getAllPromotions();
});

final promotionByIdProvider =
    FutureProvider.autoDispose.family<PromotionEntity?, int>((ref, id) async {
  final repo = ref.watch(promotionsRepositoryProvider);
  return repo.getPromotionById(id);
});

/// Promotions actives à l'instant présent, indexées par articleId —
/// utilisé pour préremplir automatiquement le prix promo à la saisie
/// d'une ligne de vente.
final activePromotionsMapProvider =
    FutureProvider.autoDispose<Map<int, PromotionEntity>>((ref) async {
  final repo = ref.watch(promotionsRepositoryProvider);
  return repo.getActivePromotionsMap();
});

/// Performance réelle d'une promotion (pneus vendus, CA, marge perdue).
final promotionPerformanceProvider = FutureProvider.autoDispose
    .family<PromotionPerformanceEntity, int>((ref, promotionId) async {
  final repo = ref.watch(promotionsRepositoryProvider);
  return repo.getPerformance(promotionId);
});
