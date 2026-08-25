import '../entities/loading.dart';

abstract class LoadingsRepository {
  Future<List<LoadingEntity>> getAllLoadings();
  Future<LoadingEntity?> getLoadingById(int id);

  Future<int> createLoading({
    String? nom,
    int? supplierId,
    required DateTime dateChargement,
    DateTime? dateArrivee,
    String? container,
    String? reference,
    String? notes,
    int? createdById,
    String? createdByNom,
  });

  Future<void> updateLoading({
    required int id,
    String? nom,
    int? supplierId,
    required DateTime dateChargement,
    DateTime? dateArrivee,
    String? container,
    String? reference,
    String? notes,
  });

  /// Fige le coût de revient : plus aucune dépense/achat rattaché
  /// n'impactera le prix de revient des articles de ce chargement.
  Future<void> cloturerLoading(int id);

  /// Réouvre un chargement clôturé (les recalculs de coût reprennent).
  Future<void> rouvrirLoading(int id);

  /// Calcule la rentabilité complète d'un chargement : stock reçu/vendu/
  /// restant, pertes, coûts (achat + dépenses imputées), prix de
  /// revient unitaire, chiffre d'affaires, marge brute, commissions
  /// commerciales et bénéfice estimé.
  Future<LoadingRentabiliteEntity> getRentabilite(int loadingId);
}
