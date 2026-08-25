import 'package:drift/drift.dart';
import 'articles_table.dart';
import 'stores_table.dart';
import 'loadings_table.dart';
import 'purchases_table.dart';

/// Registre de lots (FIFO) tenu EN PARALLÈLE du stock global
/// ([ArticleStocks], quantité fongible par article/magasin, source de
/// vérité pour la vente). Ce registre n'est jamais utilisé pour vérifier
/// la disponibilité d'un article — uniquement pour calculer le prix de
/// revient réel et la rentabilité par chargement (voir [Loadings]).
///
/// [quantiteRestante] est décrémentée par [StockLotConsumptions] au fil
/// des ventes/pertes ; [coutUnitaire] est recalculé en place tant que le
/// chargement reste ouvert (nouvelles dépenses imputées), sans jamais
/// modifier les consommations déjà enregistrées (snapshot figé).
class StockLots extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get articleId => integer().references(Articles, #id)();
  IntColumn get storeId => integer().references(Stores, #id)();

  IntColumn get loadingId =>
      integer().nullable().references(Loadings, #id)();
  IntColumn get purchaseId =>
      integer().nullable().references(Purchases, #id)();

  /// Ligne d'achat précise dont ce lot provient — élimine l'ambiguïté de
  /// [purchaseId] seul quand un achat contient plusieurs lignes pour des
  /// articles différents. Nullable pour les lots créés avant l'ajout de
  /// cette colonne (correspondance de repli via purchaseId+articleId).
  IntColumn get purchaseItemId =>
      integer().nullable().references(PurchaseItems, #id)();

  DateTimeColumn get dateEntree => dateTime()();

  RealColumn get quantiteInitiale => real()();
  RealColumn get quantiteRestante => real()();

  RealColumn get coutUnitaire => real()();

  /// 'achat' | 'ouverture' | 'retour' | 'transfert' | 'ajustement'
  TextColumn get sourceType => text()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
