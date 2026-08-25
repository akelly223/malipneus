import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/stock_lots_table.dart';
import '../tables/stock_lot_consumptions_table.dart';

part 'stock_lots_dao.g.dart';

@DriftAccessor(tables: [StockLots, StockLotConsumptions])
class StockLotsDao extends DatabaseAccessor<AppDatabase>
    with _$StockLotsDaoMixin {
  StockLotsDao(super.db);

  // ── Lots ──────────────────────────────────────────────────────────────────

  /// Lots avec un reliquat disponible pour un article/magasin, du plus
  /// ancien au plus récent (ordre FIFO).
  Future<List<StockLot>> getLotsDisponibles(int articleId, int storeId) =>
      (select(stockLots)
            ..where((l) =>
                l.articleId.equals(articleId) &
                l.storeId.equals(storeId) &
                l.quantiteRestante.isBiggerThanValue(0))
            ..orderBy([(l) => OrderingTerm.asc(l.dateEntree)]))
          .get();

  Future<List<StockLot>> getLotsForLoading(int loadingId) =>
      (select(stockLots)..where((l) => l.loadingId.equals(loadingId))).get();

  /// Lots créés par une ligne d'achat précise — utilisé pour persister
  /// le coût de revient réel (achat + dépenses imputées) calculé par
  /// LoadingCostAllocationService dans [StockLots.coutUnitaire].
  Future<List<StockLot>> getLotsByPurchaseItem(int purchaseItemId) =>
      (select(stockLots)
            ..where((l) => l.purchaseItemId.equals(purchaseItemId)))
          .get();

  /// Tous les lots d'un article avec un reliquat disponible (tous
  /// magasins/chargements confondus), utilisé pour calculer son prix de
  /// revient pondéré (moyenne des lots restants, pas seulement le
  /// dernier chargement d'origine).
  Future<List<StockLot>> getLotsAvecReliquat(int articleId) =>
      (select(stockLots)
            ..where((l) =>
                l.articleId.equals(articleId) &
                l.quantiteRestante.isBiggerThanValue(0)))
          .get();

  Future<int> createLot(StockLotsCompanion lot) => into(stockLots).insert(lot);

  Future<void> ajusterQuantiteRestante(int lotId, double delta) async {
    final lot =
        await (select(stockLots)..where((l) => l.id.equals(lotId))).getSingle();
    await (update(stockLots)..where((l) => l.id.equals(lotId))).write(
      StockLotsCompanion(
        quantiteRestante: Value(lot.quantiteRestante + delta),
      ),
    );
  }

  /// Recalcule le coût unitaire des lots encore ouverts d'un chargement
  /// (nouvelle dépense imputée) — n'affecte jamais les consommations déjà
  /// enregistrées (snapshot figé sur [StockLotConsumptions]).
  Future<void> mettreAJourCoutUnitaire(int lotId, double coutUnitaire) =>
      (update(stockLots)..where((l) => l.id.equals(lotId))).write(
        StockLotsCompanion(coutUnitaire: Value(coutUnitaire)),
      );

  // ── Consommations ─────────────────────────────────────────────────────────

  Future<int> createConsumption(StockLotConsumptionsCompanion consumption) =>
      into(stockLotConsumptions).insert(consumption);

  Future<List<StockLotConsumption>> getConsumptionsForMovement(
          int movementId) =>
      (select(stockLotConsumptions)
            ..where((c) => c.movementId.equals(movementId)))
          .get();

  Future<int> deleteConsumption(int id) =>
      (delete(stockLotConsumptions)..where((c) => c.id.equals(id))).go();

  /// Consommations liées à un chargement (via les lots de ce chargement),
  /// utilisées pour calculer la quantité vendue attribuable au chargement.
  Future<List<StockLotConsumption>> getConsumptionsForLoading(
      int loadingId) async {
    final db = attachedDatabase;
    final rows = await db.customSelect(
      '''
      SELECT c.* FROM stock_lot_consumptions c
      JOIN stock_lots l ON l.id = c.stock_lot_id
      WHERE l.loading_id = ?
      ''',
      variables: [Variable.withInt(loadingId)],
      readsFrom: {stockLotConsumptions, stockLots},
    ).get();
    return rows.map((r) => stockLotConsumptions.map(r.data)).toList();
  }
}
