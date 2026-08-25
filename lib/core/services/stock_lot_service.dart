import 'package:drift/drift.dart';
import '../../data/local/database.dart';

/// Registre de lots (FIFO) tenu EN PARALLÈLE du stock global
/// ([ArticleStocks], seule source de vérité pour la vente/disponibilité,
/// jamais modifiée par ce service). Permet de calculer le prix de
/// revient réel et la rentabilité par chargement (sections 12-15).
///
/// Appelé en PLUS de `articlesDao.adjustStock` + `stockDao.createMovement`
/// à chaque point d'écriture existant du stock — jamais à la place.
/// Si les lots ne suffisent pas à couvrir une sortie (stock antérieur à
/// la mise en place des chargements, ou dérive), le solde est consommé
/// "hors lot" au coût `articles.prix_achat` courant : jamais bloquant,
/// jamais une exception ne doit empêcher la vente/le mouvement réel.
class StockLotService {
  final AppDatabase _db;

  StockLotService(this._db);

  /// Crée un nouveau lot (entrée de stock datée). Utilisé pour les
  /// achats (avec [loadingId]/[purchaseId] si rattachés à un
  /// chargement), les retours, les transferts entrants et les
  /// corrections positives d'inventaire.
  Future<int> enregistrerEntree({
    required int articleId,
    required int storeId,
    required double quantite,
    required double coutUnitaire,
    int? loadingId,
    int? purchaseId,
    int? purchaseItemId,
    String sourceType = 'achat',
  }) {
    if (quantite <= 0) return Future.value(0);
    return _db.stockLotsDao.createLot(StockLotsCompanion.insert(
      articleId: articleId,
      storeId: storeId,
      loadingId: Value(loadingId),
      purchaseId: Value(purchaseId),
      purchaseItemId: Value(purchaseItemId),
      dateEntree: DateTime.now(),
      quantiteInitiale: quantite,
      quantiteRestante: quantite,
      coutUnitaire: coutUnitaire,
      sourceType: sourceType,
    ));
  }

  /// Consomme [quantite] unités en FIFO (lot le plus ancien d'abord)
  /// pour un article/magasin. Retourne le coût total consommé (utile
  /// pour un calcul de marge immédiat). [movementId] ancre la
  /// consommation sur la ligne d'audit `stock_movements` correspondante
  /// (permet de la retrouver/annuler via [restaurer]) ; [documentLineId]
  /// relie directement une ligne de vente à son coût réel.
  Future<double> consommerFifo({
    required int articleId,
    required int storeId,
    required double quantite,
    int? movementId,
    int? documentLineId,
  }) async {
    if (quantite <= 0) return 0;

    var restant = quantite;
    double coutTotal = 0;

    final lots = await _db.stockLotsDao.getLotsDisponibles(articleId, storeId);
    for (final lot in lots) {
      if (restant <= 0.0001) break;
      final pris =
          restant < lot.quantiteRestante ? restant : lot.quantiteRestante;
      if (pris <= 0) continue;

      await _db.stockLotsDao.ajusterQuantiteRestante(lot.id, -pris);
      await _db.stockLotsDao.createConsumption(
        StockLotConsumptionsCompanion.insert(
          stockLotId: Value(lot.id),
          articleId: articleId,
          storeId: storeId,
          quantite: pris,
          coutUnitaireSnapshot: lot.coutUnitaire,
          documentLineId: Value(documentLineId),
          movementId: Value(movementId),
        ),
      );
      coutTotal += pris * lot.coutUnitaire;
      restant -= pris;
    }

    // Solde non couvert par des lots connus : consommation "hors lot"
    // au prix d'achat courant de l'article, jamais bloquant.
    if (restant > 0.0001) {
      final article = await _db.articlesDao.getArticleById(articleId);
      final coutFallback = article?.prixAchat ?? 0;
      await _db.stockLotsDao.createConsumption(
        StockLotConsumptionsCompanion.insert(
          stockLotId: const Value(null),
          articleId: articleId,
          storeId: storeId,
          quantite: restant,
          coutUnitaireSnapshot: coutFallback,
          documentLineId: Value(documentLineId),
          movementId: Value(movementId),
        ),
      );
      coutTotal += restant * coutFallback;
    }

    return coutTotal;
  }

  /// Annule les consommations liées à un mouvement de stock donné
  /// (ex : vente/BL annulé, facture modifiée) : restaure le reliquat
  /// des lots concernés et supprime les lignes de consommation. N'est
  /// PAS un historique officiel — l'audit reste `stock_movements`
  /// (jamais modifié) ; ces lignes reflètent l'état courant de
  /// l'allocation FIFO.
  Future<void> restaurer(int movementId) async {
    final consumptions =
        await _db.stockLotsDao.getConsumptionsForMovement(movementId);
    for (final c in consumptions) {
      if (c.stockLotId != null) {
        await _db.stockLotsDao.ajusterQuantiteRestante(c.stockLotId!, c.quantite);
      }
      await _db.stockLotsDao.deleteConsumption(c.id);
    }
  }

  /// Réduit le reliquat des lots créés par un achat donné pour un
  /// article (utilisé lors de la modification d'un achat déjà
  /// réceptionné, avant réapplication des nouvelles lignes). Ne
  /// supprime jamais de lot (une contrainte de clé étrangère empêcherait
  /// de toute façon la suppression d'un lot déjà consommé) — réduit
  /// seulement la quantité restante, au plus jusqu'à 0.
  Future<void> reduireLotsAchat({
    required int purchaseId,
    required int articleId,
    required double quantite,
    int? purchaseItemId,
  }) async {
    if (quantite <= 0) return;
    var restant = quantite;
    // Correspondance précise par ligne d'achat quand elle est connue
    // (élimine l'ambiguïté d'un achat multi-lignes pour le même
    // article) ; repli sur (purchaseId, articleId) pour les lots créés
    // avant l'ajout de purchaseItemId.
    final lotsAchat = purchaseItemId != null
        ? await (_db.select(_db.stockLots)
              ..where((l) => l.purchaseItemId.equals(purchaseItemId)))
            .get()
        : await (_db.select(_db.stockLots)
              ..where((l) =>
                  l.purchaseId.equals(purchaseId) &
                  l.articleId.equals(articleId)))
            .get();
    for (final lot in lotsAchat) {
      if (restant <= 0.0001) break;
      final retire =
          restant < lot.quantiteRestante ? restant : lot.quantiteRestante;
      if (retire <= 0) continue;
      await _db.stockLotsDao.ajusterQuantiteRestante(lot.id, -retire);
      restant -= retire;
    }
  }
}
