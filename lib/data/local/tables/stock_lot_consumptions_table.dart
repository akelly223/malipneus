import 'package:drift/drift.dart';
import 'stock_lots_table.dart';
import 'articles_table.dart';
import 'stores_table.dart';
import 'document_lines_table.dart';
import 'stock_movements_table.dart';

/// Ligne de consommation FIFO d'un lot ([StockLots]).
///
/// [stockLotId] est nullable : null signifie une consommation "hors
/// lot", en secours quand les lots enregistrés ne suffisent pas à
/// couvrir une sortie (ex: stock antérieur à la mise en place des
/// chargements). Dans ce cas [coutUnitaireSnapshot] utilise le
/// `articles.prix_achat` courant.
///
/// [movementId] ancre cette consommation sur la ligne d'audit
/// [StockMovements] correspondante (créée par TOUS les chemins
/// d'écriture stock existants), ce qui permet de retrouver/annuler une
/// consommation sans dupliquer la logique de traçabilité déjà en place.
/// [documentLineId] est renseigné uniquement pour une vente (V2), pour
/// relier directement une ligne vendue à son coût réel.
///
/// Contrairement à [DocumentLines] ou [StockMovements], ces lignes
/// peuvent être supprimées lors d'une restauration (annulation de
/// vente/BL) : elles ne sont pas un historique financier officiel, mais
/// l'état courant de l'allocation FIFO. L'historique officiel reste
/// [StockMovements] (jamais modifié) et [DocumentHistories].
class StockLotConsumptions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get stockLotId =>
      integer().nullable().references(StockLots, #id)();

  IntColumn get articleId => integer().references(Articles, #id)();
  IntColumn get storeId => integer().references(Stores, #id)();

  RealColumn get quantite => real()();
  RealColumn get coutUnitaireSnapshot => real()();

  IntColumn get documentLineId =>
      integer().nullable().references(DocumentLines, #id)();
  IntColumn get movementId =>
      integer().nullable().references(StockMovements, #id)();

  DateTimeColumn get dateConsommation =>
      dateTime().withDefault(currentDateAndTime)();
}
