import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/loading.dart';
import '../../../domain/entities/purchase.dart';

final loadingsListProvider =
    FutureProvider.autoDispose<List<LoadingEntity>>((ref) async {
  final repo = ref.watch(loadingsRepositoryProvider);
  return repo.getAllLoadings();
});

final loadingByIdProvider =
    FutureProvider.autoDispose.family<LoadingEntity?, int>((ref, id) async {
  final repo = ref.watch(loadingsRepositoryProvider);
  return repo.getLoadingById(id);
});

final loadingRentabiliteProvider = FutureProvider.autoDispose
    .family<LoadingRentabiliteEntity, int>((ref, loadingId) async {
  final repo = ref.watch(loadingsRepositoryProvider);
  return repo.getRentabilite(loadingId);
});

/// Achats rattachés à un chargement (filtrage côté client — le volume
/// par chargement reste faible).
final purchasesForLoadingProvider = FutureProvider.autoDispose
    .family<List<PurchaseEntity>, int>((ref, loadingId) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  final all = await repo.getAllPurchases();
  return all.where((p) => p.chargementId == loadingId).toList();
});
