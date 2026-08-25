import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/purchase_cart_item_input.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../../core/constants/db_constants.dart';
import '../../core/services/stock_lot_service.dart';
import '../../core/services/loading_cost_allocation_service.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  final AppDatabase db;
  late final StockLotService _lots;

  PurchaseRepositoryImpl(this.db) {
    _lots = StockLotService(db);
  }

  double _calculerTotal(
      List<PurchaseCartItemInput> items, double remiseGlobale) {
    final sousTotal = items.fold<double>(0, (s, i) => s + i.totalLigne);
    final total = sousTotal - remiseGlobale;
    return total < 0 ? 0 : total;
  }

  Future<PurchaseEntity> _toEntity(Purchase purchase) async {
    final itemRows = await db.purchasesDao.getItemsForPurchase(purchase.id);
    final items = <PurchaseItemEntity>[];
    for (final it in itemRows) {
      final article = await db.articlesDao.getArticleById(it.articleId);
      items.add(PurchaseItemEntity(
        id: it.id,
        purchaseId: it.purchaseId,
        articleId: it.articleId,
        articleNom: article?.nom ?? '???',
        quantite: it.quantite,
        prixAchatUnitaire: it.prixAchatUnitaire,
        totalLigne: it.totalLigne,
      ));
    }
    final supplier = await db.suppliersDao.getSupplierById(purchase.supplierId);
    final store = await db.storesDao.getStoreById(purchase.storeId);
    final user = await db.usersDao.getUserById(purchase.userId);
    final modifiePar = purchase.modifieParUserId != null
        ? await db.usersDao.getUserById(purchase.modifieParUserId!)
        : null;
    final chargement = purchase.chargementId != null
        ? await db.loadingsDao.getLoadingById(purchase.chargementId!)
        : null;

    return PurchaseEntity(
      id: purchase.id,
      numero: purchase.numero,
      supplierId: purchase.supplierId,
      supplierNom: supplier?.nom,
      supplierTelephone: supplier?.telephone,
      supplierAdresse: supplier?.adresse,
      storeId: purchase.storeId,
      storeNom: store?.nom,
      userId: purchase.userId,
      userNom: user?.nom,
      dateCreation: purchase.dateCreation,
      totalHt: purchase.totalHt,
      remiseGlobale: purchase.remiseGlobale,
      totalFinal: purchase.totalFinal,
      montantPaye: purchase.montantPaye,
      statutPaiement: purchase.statutPaiement,
      statut: purchase.statut,
      dateModification: purchase.dateModification,
      modifieParNom: modifiePar?.nom,
      items: items,
      chargementId: purchase.chargementId,
      chargementNumero: chargement?.numero,
    );
  }

  @override
  Future<List<PurchaseEntity>> getAllPurchases() async {
    final purchases = await db.purchasesDao.getAllPurchases();
    final result = <PurchaseEntity>[];
    for (final p in purchases) {
      result.add(await _toEntity(p));
    }
    return result;
  }

  @override
  Future<PurchaseEntity?> getPurchaseById(int id) async {
    final purchase = await db.purchasesDao.getPurchaseById(id);
    return purchase == null ? null : _toEntity(purchase);
  }

  @override
  Future<List<PurchaseEntity>> getPurchasesForSupplier(int supplierId) async {
    final purchases = await db.purchasesDao.getPurchasesForSupplier(supplierId);
    final result = <PurchaseEntity>[];
    for (final p in purchases) {
      result.add(await _toEntity(p));
    }
    return result;
  }

  @override
  Future<List<PurchaseEntity>> searchPurchases(String query) async {
    final purchases = await db.purchasesDao.searchPurchases(query);
    final result = <PurchaseEntity>[];
    for (final p in purchases) {
      result.add(await _toEntity(p));
    }
    return result;
  }

  /// Crée un achat fournisseur complet : augmente le stock par
  /// article, met à jour leur prix d'achat de référence (pour que la
  /// marge calculée au dashboard reste juste), enregistre un
  /// mouvement de stock "entrée" par ligne, calcule le statut de
  /// paiement, et enregistre le paiement initial s'il y en a un.
  @override
  Future<int> createPurchase({
    required int supplierId,
    required int storeId,
    required int userId,
    required List<PurchaseCartItemInput> items,
    double remiseGlobale = 0,
    double montantPayeInitial = 0,
    String? modePaiementInitial,
    String statut = 'recu',
    int? chargementId,
    DateTime? dateAchat,
  }) async {
    return db.transaction(() async {
      final numero = await db.purchasesDao.generateNextNumero();
      final sousTotal = items.fold<double>(0, (s, i) => s + i.totalLigne);
      final totalFinal = _calculerTotal(items, remiseGlobale);

      String statutPaiement;
      if (montantPayeInitial >= totalFinal && totalFinal > 0) {
        statutPaiement = DbConstants.invoiceStatusPaye;
      } else if (montantPayeInitial > 0) {
        statutPaiement = DbConstants.invoiceStatusPartiel;
      } else {
        statutPaiement = DbConstants.invoiceStatusNonPaye;
      }

      final (purchaseId, itemIds) = await db.purchasesDao.createPurchaseWithItems(
        PurchasesCompanion.insert(
          numero: numero,
          supplierId: supplierId,
          storeId: storeId,
          userId: userId,
          dateCreation:
              dateAchat != null ? Value(dateAchat) : const Value.absent(),
          totalHt: Value(sousTotal),
          remiseGlobale: Value(remiseGlobale),
          totalFinal: Value(totalFinal),
          montantPaye: Value(montantPayeInitial),
          statutPaiement: Value(statutPaiement),
          statut: Value(statut),
          chargementId: Value(chargementId),
        ),
        items
            .map((i) => PurchaseItemsCompanion.insert(
                  purchaseId: 0, // remplacé par le DAO lors de l'insertion
                  articleId: i.articleId,
                  quantite: i.quantite,
                  prixAchatUnitaire: i.prixAchatUnitaire,
                  totalLigne: i.totalLigne,
                ))
            .toList(),
      );

      // Un bon de commande n'impacte pas encore le stock : ça n'aura
      // lieu qu'à la réception (voir receptionnerCommande).
      if (statut == DbConstants.purchaseStatutRecu) {
        // Augmente le stock, trace chaque entrée, et met à jour le prix
        // d'achat de référence de l'article.
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          await db.articlesDao.adjustStock(
            articleId: item.articleId,
            storeId: storeId,
            delta: item.quantite,
          );
          await db.stockDao.createMovement(StockMovementsCompanion.insert(
            articleId: item.articleId,
            storeId: storeId,
            typeMouvement: DbConstants.movementEntree,
            quantite: item.quantite,
            reference: Value(numero),
            userId: userId,
          ));

          await db.customStatement(
            'UPDATE articles SET prix_achat = ? WHERE id = ?',
            [item.prixAchatUnitaire, item.articleId],
          );
          if (chargementId != null) {
            await db.customStatement(
              'UPDATE articles SET chargement_origine_id = ? WHERE id = ?',
              [chargementId, item.articleId],
            );
          }

          await _lots.enregistrerEntree(
            articleId: item.articleId,
            storeId: storeId,
            quantite: item.quantite,
            coutUnitaire: item.prixAchatUnitaire,
            loadingId: chargementId,
            purchaseId: purchaseId,
            purchaseItemId: itemIds[i],
          );
        }
        if (chargementId != null) {
          await LoadingCostAllocationService(db).recalculer(chargementId);
        }
      }

      // Enregistre le paiement initial s'il y en a un, avec son reçu.
      if (montantPayeInitial > 0 && modePaiementInitial != null) {
        final numeroRecu =
            await db.documentCountersDao.genererProchainNumero('REC');
        await db.paymentsDao.createPayment(PaymentsCompanion.insert(
          purchaseId: Value(purchaseId),
          montant: montantPayeInitial,
          modePaiement: modePaiementInitial,
          userId: userId,
          numeroRecu: Value(numeroRecu),
        ));
      }

      return purchaseId;
    });
  }

  /// Réceptionne un bon de commande : applique l'entrée de stock
  /// (augmentation, mouvement de stock, prix d'achat de référence) et
  /// fait passer le statut à 'recu'. Ne fait rien si l'achat n'est
  /// pas un bon de commande en attente (idempotent en cas de double-clic).
  @override
  Future<void> receptionnerCommande({
    required int purchaseId,
    required int userId,
  }) async {
    final purchase = await db.purchasesDao.getPurchaseById(purchaseId);
    if (purchase == null || purchase.statut != DbConstants.purchaseStatutCommande) {
      return;
    }
    final items = await db.purchasesDao.getItemsForPurchase(purchaseId);

    await db.transaction(() async {
      for (final item in items) {
        await db.articlesDao.adjustStock(
          articleId: item.articleId,
          storeId: purchase.storeId,
          delta: item.quantite,
        );
        await db.stockDao.createMovement(StockMovementsCompanion.insert(
          articleId: item.articleId,
          storeId: purchase.storeId,
          typeMouvement: DbConstants.movementEntree,
          quantite: item.quantite,
          reference: Value(purchase.numero),
          userId: userId,
        ));
        await db.customStatement(
          'UPDATE articles SET prix_achat = ? WHERE id = ?',
          [item.prixAchatUnitaire, item.articleId],
        );
        if (purchase.chargementId != null) {
          await db.customStatement(
            'UPDATE articles SET chargement_origine_id = ? WHERE id = ?',
            [purchase.chargementId, item.articleId],
          );
        }
        await _lots.enregistrerEntree(
          articleId: item.articleId,
          storeId: purchase.storeId,
          quantite: item.quantite,
          coutUnitaire: item.prixAchatUnitaire,
          loadingId: purchase.chargementId,
          purchaseId: purchaseId,
          purchaseItemId: item.id,
        );
      }

      await db.purchasesDao.marquerCommeRecue(purchaseId);
    });
    if (purchase.chargementId != null) {
      await LoadingCostAllocationService(db).recalculer(purchase.chargementId!);
    }
  }

  @override
  Future<void> updatePurchase({
    required int purchaseId,
    required int supplierId,
    required int storeId,
    required int modifieParUserId,
    required List<PurchaseCartItemInput> items,
    double remiseGlobale = 0,
    DateTime? dateAchat,
  }) async {
    final existant = await db.purchasesDao.getPurchaseById(purchaseId);
    if (existant == null) throw Exception('Achat introuvable');

    // Un bon de commande pas encore réceptionné n'a jamais eu d'effet
    // sur le stock : sa modification ne doit donc pas non plus en
    // avoir (voir receptionnerCommande pour l'entrée réelle en stock).
    final impacteStock = existant.statut == DbConstants.purchaseStatutRecu;

    final anciennesLignes =
        await db.purchasesDao.getItemsForPurchase(purchaseId);

    await db.transaction(() async {
      // ÉTAPE 1 : Annulation des effets de l'ancien achat sur le stock.
      // Chaque ancienne quantité est soustraite du magasin d'origine,
      // et un mouvement de sortie de correction est enregistré pour
      // maintenir l'historique traçable.
      if (impacteStock) {
        for (final ancienne in anciennesLignes) {
          await db.articlesDao.adjustStock(
            articleId: ancienne.articleId,
            storeId: existant.storeId, // magasin de l'achat original
            delta: -ancienne.quantite,
          );
          await db.stockDao.createMovement(StockMovementsCompanion.insert(
            articleId: ancienne.articleId,
            storeId: existant.storeId,
            typeMouvement: DbConstants.movementSortie,
            quantite: ancienne.quantite,
            reference: Value('CORRECTION-${existant.numero}'),
            userId: modifieParUserId,
          ));
          await _lots.reduireLotsAchat(
            purchaseId: purchaseId,
            articleId: ancienne.articleId,
            quantite: ancienne.quantite,
            purchaseItemId: ancienne.id,
          );
        }
      }

      // Les anciennes lignes d'achat vont être supprimées (ÉTAPE 2) —
      // les lots de stock qu'elles ont créés ne sont eux jamais
      // supprimés (contrainte de clé étrangère depuis
      // stock_lot_consumptions, et historique FIFO à préserver), mais
      // leur purchase_item_id doit être détaché en premier pour ne pas
      // violer la contrainte de clé étrangère lors de la suppression
      // des lignes. Un lot ainsi détaché retombe sur la correspondance
      // de repli (purchaseId, articleId) — sans effet ici puisque
      // ÉTAPE 1 les a déjà réduits à 0 (entièrement remplacés par les
      // nouvelles lignes de l'ÉTAPE 3).
      await db.customStatement(
        'UPDATE stock_lots SET purchase_item_id = NULL WHERE purchase_id = ?',
        [purchaseId],
      );

      // ÉTAPE 2 : Application du nouvel achat.
      final sousTotal = items.fold<double>(0, (s, i) => s + i.totalLigne);
      final totalFinal = _calculerTotal(items, remiseGlobale);

      final itemIds = await db.purchasesDao.updatePurchaseWithItems(
        purchaseId,
        PurchasesCompanion(
          supplierId: Value(supplierId),
          storeId: Value(storeId),
          totalHt: Value(sousTotal),
          remiseGlobale: Value(remiseGlobale),
          totalFinal: Value(totalFinal),
          dateCreation:
              dateAchat != null ? Value(dateAchat) : const Value.absent(),
          dateModification: Value(DateTime.now()),
          modifieParUserId: Value(modifieParUserId),
        ),
        items
            .map((i) => PurchaseItemsCompanion.insert(
                  // purchaseId est injecté par updatePurchaseWithItems
                  // via copyWith — on passe 0 ici comme placeholder.
                  purchaseId: 0,
                  articleId: i.articleId,
                  quantite: i.quantite,
                  prixAchatUnitaire: i.prixAchatUnitaire,
                  totalLigne: i.totalLigne,
                ))
            .toList(),
      );

      // ÉTAPE 3 : Application des nouvelles entrées de stock.
      if (!impacteStock) return;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        await db.articlesDao.adjustStock(
          articleId: item.articleId,
          storeId: storeId,
          delta: item.quantite,
        );
        await db.stockDao.createMovement(StockMovementsCompanion.insert(
          articleId: item.articleId,
          storeId: storeId,
          typeMouvement: DbConstants.movementEntree,
          quantite: item.quantite,
          reference: Value('MOD-${existant.numero}'),
          userId: modifieParUserId,
        ));
        // Met à jour le prix d'achat de référence de l'article via
        // une mise à jour SQL ciblée — Article n'a pas de copyWith()
        // généré par Drift dans cette version.
        await db.customStatement(
          'UPDATE articles SET prix_achat = ? WHERE id = ?',
          [item.prixAchatUnitaire, item.articleId],
        );
        if (existant.chargementId != null) {
          await db.customStatement(
            'UPDATE articles SET chargement_origine_id = ? WHERE id = ?',
            [existant.chargementId, item.articleId],
          );
        }
        await _lots.enregistrerEntree(
          articleId: item.articleId,
          storeId: storeId,
          quantite: item.quantite,
          coutUnitaire: item.prixAchatUnitaire,
          purchaseItemId: itemIds[i],
          loadingId: existant.chargementId,
          purchaseId: purchaseId,
        );
      }
    });

    if (impacteStock && existant.chargementId != null) {
      await LoadingCostAllocationService(db).recalculer(existant.chargementId!);
    }
  }

  @override
  Future<double> getTotalAchatsForSupplier(int supplierId) async {
    final purchases = await db.purchasesDao.getPurchasesForSupplier(supplierId);
    return purchases.fold<double>(0, (sum, p) => sum + p.totalFinal);
  }

  @override
  Future<void> deletePurchase(int id) async {
    await (db.delete(db.purchases)..where((p) => p.id.equals(id))).go();
  }
}
