import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/purchases_table.dart';

part 'purchases_dao.g.dart';

@DriftAccessor(tables: [Purchases, PurchaseItems])
class PurchasesDao extends DatabaseAccessor<AppDatabase>
    with _$PurchasesDaoMixin {
  PurchasesDao(super.db);

  Future<List<Purchase>> getAllPurchases() => (select(purchases)
        ..orderBy([(p) => OrderingTerm.desc(p.dateCreation)]))
      .get();

  Future<Purchase?> getPurchaseById(int id) =>
      (select(purchases)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Remplace entièrement les lignes d'un achat et met à jour son
  /// en-tête en une seule transaction atomique. Retourne les ids des
  /// nouvelles lignes créées, dans le même ordre que [nouvellesLignes]
  /// (utilisé pour rattacher précisément chaque lot de stock à sa ligne
  /// d'achat, voir StockLots.purchaseItemId).
  Future<List<int>> updatePurchaseWithItems(
    int purchaseId,
    PurchasesCompanion header,
    List<PurchaseItemsCompanion> nouvellesLignes,
  ) {
    return transaction(() async {
      await (delete(purchaseItems)
            ..where((i) => i.purchaseId.equals(purchaseId)))
          .go();
      final itemIds = <int>[];
      for (final item in nouvellesLignes) {
        final itemId = await into(purchaseItems)
            .insert(item.copyWith(purchaseId: Value(purchaseId)));
        itemIds.add(itemId);
      }
      await (update(purchases)..where((p) => p.id.equals(purchaseId)))
          .write(header);
      return itemIds;
    });
  }

  /// Retourne les lignes actuelles pour permettre l'annulation de
  /// leur effet sur le stock avant modification.
  Future<List<PurchaseItem>> getItemsForPurchase(int purchaseId) =>
      (select(purchaseItems)..where((i) => i.purchaseId.equals(purchaseId)))
          .get();

  Future<List<Purchase>> getPurchasesForSupplier(int supplierId) =>
      (select(purchases)
            ..where((p) => p.supplierId.equals(supplierId))
            ..orderBy([(p) => OrderingTerm.desc(p.dateCreation)]))
          .get();

  Future<List<Purchase>> searchPurchases(String query) {
    final likeQuery = '%$query%';
    return (select(purchases)..where((p) => p.numero.like(likeQuery))).get();
  }

  /// Crée un achat avec ses lignes en une seule transaction. Retourne
  /// l'id de l'achat et les ids des lignes créées, dans le même ordre
  /// que [items] (utilisé pour rattacher précisément chaque lot de
  /// stock à sa ligne d'achat, voir StockLots.purchaseItemId).
  Future<(int purchaseId, List<int> itemIds)> createPurchaseWithItems(
    PurchasesCompanion purchase,
    List<PurchaseItemsCompanion> items,
  ) {
    return transaction(() async {
      final purchaseId = await into(purchases).insert(purchase);
      final itemIds = <int>[];
      for (final item in items) {
        final itemId = await into(purchaseItems)
            .insert(item.copyWith(purchaseId: Value(purchaseId)));
        itemIds.add(itemId);
      }
      return (purchaseId, itemIds);
    });
  }

  /// Met à jour le montant payé et recalcule le statut de paiement.
  Future<void> updateMontantPaye(
      int purchaseId, double nouveauMontantPaye, double totalFinal) async {
    String statut;
    if (nouveauMontantPaye >= totalFinal) {
      statut = 'paye';
    } else if (nouveauMontantPaye > 0) {
      statut = 'partiel';
    } else {
      statut = 'non_paye';
    }
    await (update(purchases)..where((p) => p.id.equals(purchaseId))).write(
      PurchasesCompanion(
        montantPaye: Value(nouveauMontantPaye),
        statutPaiement: Value(statut),
      ),
    );
  }

  /// Génère le prochain numéro séquentiel d'achat pour l'année en
  /// cours, ex: ACH-2026-0001. Délègue à un compteur dédié, jamais
  /// décrémenté même si un achat est supprimé.
  Future<String> generateNextNumero() =>
      attachedDatabase.documentCountersDao.genererProchainNumero('ACH');

  /// Fait passer un bon de commande au statut 'recu' une fois la
  /// marchandise réceptionnée.
  Future<void> marquerCommeRecue(int purchaseId) =>
      (update(purchases)..where((p) => p.id.equals(purchaseId)))
          .write(const PurchasesCompanion(statut: Value('recu')));
}
