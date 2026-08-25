import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/stock_movements_table.dart';
import '../tables/stock_transfers_table.dart';

part 'stock_dao.g.dart';

@DriftAccessor(tables: [StockMovements, StockTransfers])
class StockDao extends DatabaseAccessor<AppDatabase> with _$StockDaoMixin {
  StockDao(super.db);

  Future<List<StockMovement>> getAllMovements() => (select(stockMovements)
        ..orderBy([(m) => OrderingTerm.desc(m.dateMouvement)]))
      .get();

  Future<List<StockMovement>> getMovementsForArticle(int articleId) =>
      (select(stockMovements)
            ..where((m) => m.articleId.equals(articleId))
            ..orderBy([(m) => OrderingTerm.desc(m.dateMouvement)]))
          .get();

  Future<int> createMovement(StockMovementsCompanion movement) =>
      into(stockMovements).insert(movement);

  /// Types de mouvement pour un lot d'identifiants, utilisé pour
  /// classifier les consommations de lots (vente/perte/ajustement) sans
  /// une requête par ligne (voir LoadingsRepositoryImpl.getRentabilite).
  Future<Map<int, String>> getTypesPourMouvements(List<int> ids) async {
    if (ids.isEmpty) return {};
    final rows = await (select(stockMovements)
          ..where((m) => m.id.isIn(ids)))
        .get();
    return {for (final r in rows) r.id: r.typeMouvement};
  }

  Future<List<StockTransfer>> getAllTransfers() => (select(stockTransfers)
        ..orderBy([(t) => OrderingTerm.desc(t.dateTransfert)]))
      .get();

  /// Crée un transfert entre deux magasins. Les deux mouvements de
  /// stock associés (sortie source / entrée destination) sont créés
  /// par le repository, qui orchestre aussi l'ajustement des
  /// quantités via ArticlesDao (transaction globale).
  Future<int> createTransfer(StockTransfersCompanion transfer) =>
      into(stockTransfers).insert(transfer);
}
