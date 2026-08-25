import 'package:drift/drift.dart';
import '../../data/local/database.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_type.dart';
import 'stock_lot_service.dart';

/// Applique ou reverse les impacts de stock liés aux pièces commerciales.
///
/// Seuls le BL (sortie) et le BR (entrée) ont un impact stock.
/// Chaque opération est idempotente via la transaction SQLite.
class StockImpactService {
  final AppDatabase _db;
  late final StockLotService _lots;

  StockImpactService(this._db) {
    _lots = StockLotService(_db);
  }

  /// Décrémente le stock pour chaque ligne du BL.
  /// Appelé lors de la validation d'un bon de livraison.
  Future<void> appliquerSortieBonLivraison(
      DocumentEntity bl, int userId) async {
    assert(bl.type == DocumentType.bonLivraison,
        'appliquerSortieBonLivraison appelé sur ${bl.type.libelle}');

    for (final ligne in bl.lignes) {
      await _db.articlesDao.adjustStock(
        articleId: ligne.articleId,
        storeId: bl.storeId,
        delta: -ligne.quantite,
      );
      final movementId = await _db.stockDao.createMovement(
        StockMovementsCompanion.insert(
          articleId: ligne.articleId,
          storeId: bl.storeId,
          typeMouvement: 'sortie',
          quantite: ligne.quantite,
          reference: Value('BL:${bl.numero}'),
          userId: userId,
        ),
      );
      await _lots.consommerFifo(
        articleId: ligne.articleId,
        storeId: bl.storeId,
        quantite: ligne.quantite,
        movementId: movementId,
        documentLineId: ligne.id,
      );
    }
  }

  /// Reverse la sortie stock d'un BL (lors de son annulation).
  Future<void> reverserSortieBonLivraison(
      DocumentEntity bl, int userId) async {
    assert(bl.type == DocumentType.bonLivraison);

    for (final ligne in bl.lignes) {
      await _db.articlesDao.adjustStock(
        articleId: ligne.articleId,
        storeId: bl.storeId,
        delta: ligne.quantite,
      );
      await _db.stockDao.createMovement(
        StockMovementsCompanion.insert(
          articleId: ligne.articleId,
          storeId: bl.storeId,
          typeMouvement: 'entree',
          quantite: ligne.quantite,
          reference: Value('BL-ANNULE:${bl.numero}'),
          userId: userId,
        ),
      );
      // Réintègre un lot pour la quantité annulée, au prix d'achat de
      // référence de l'article (jamais au prix de vente de la ligne —
      // fausserait le prix de revient) : meilleure estimation disponible
      // sans lien direct vers les lots consommés par la sortie d'origine.
      await _lots.enregistrerEntree(
        articleId: ligne.articleId,
        storeId: bl.storeId,
        quantite: ligne.quantite,
        coutUnitaire: await _coutAchatArticle(ligne.articleId),
        sourceType: 'retour',
      );
    }
  }

  /// Incrémente le stock pour chaque ligne du BR.
  /// Appelé lors de la validation d'un bon de retour.
  Future<void> appliquerEntreeBonRetour(
      DocumentEntity br, int userId) async {
    assert(br.type == DocumentType.bonRetour);

    for (final ligne in br.lignes) {
      await _db.articlesDao.adjustStock(
        articleId: ligne.articleId,
        storeId: br.storeId,
        delta: ligne.quantite,
      );
      await _db.stockDao.createMovement(
        StockMovementsCompanion.insert(
          articleId: ligne.articleId,
          storeId: br.storeId,
          typeMouvement: 'entree',
          quantite: ligne.quantite,
          reference: Value('BR:${br.numero}'),
          userId: userId,
        ),
      );
      await _lots.enregistrerEntree(
        articleId: ligne.articleId,
        storeId: br.storeId,
        quantite: ligne.quantite,
        coutUnitaire: await _coutAchatArticle(ligne.articleId),
        sourceType: 'retour',
      );
    }
  }

  Future<double> _coutAchatArticle(int articleId) async {
    final article = await _db.articlesDao.getArticleById(articleId);
    return article?.prixAchat ?? 0;
  }
}
