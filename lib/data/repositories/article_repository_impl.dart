import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/article_repository.dart';
import '../../core/services/loading_cost_allocation_service.dart';

class ArticleRepositoryImpl implements ArticleRepository {
  final AppDatabase db;

  ArticleRepositoryImpl(this.db);

  /// Prix de revient réel d'un article : moyenne PONDÉRÉE par la
  /// quantité restante des lots de stock encore disponibles (tous
  /// chargements confondus) — un article peut avoir du stock provenant
  /// de plusieurs chargements à des coûts différents (réalité FIFO),
  /// donc jamais une simple moyenne du dernier chargement d'origine.
  /// Coûteux (requête supplémentaire) : réservé aux vues détail, jamais
  /// aux listes.
  Future<double?> _prixRevientPondere(int articleId) async {
    final lots = await db.stockLotsDao.getLotsAvecReliquat(articleId);
    if (lots.isEmpty) return null;
    final quantite = lots.fold<double>(0, (s, l) => s + l.quantiteRestante);
    if (quantite <= 0) return null;
    final cout =
        lots.fold<double>(0, (s, l) => s + l.quantiteRestante * l.coutUnitaire);
    return cout / quantite;
  }

  Future<ArticleEntity> _toEntity(Article a) async {
    String? categorieNom;
    if (a.categorieId != null) {
      final cats = await db.articlesDao.getAllCategories();
      categorieNom = cats
          .firstWhere(
            (c) => c.id == a.categorieId,
            orElse: () => Category(id: -1, nom: ''),
          )
          .nom;
      if (categorieNom != null && categorieNom.isEmpty) categorieNom = null;
    }
    String? chargementOrigineNumero;
    if (a.chargementOrigineId != null) {
      final chargement =
          await db.loadingsDao.getLoadingById(a.chargementOrigineId!);
      chargementOrigineNumero = chargement?.numero;
    }
    return ArticleEntity(
      id: a.id,
      code: a.code,
      nom: a.nom,
      categorieId: a.categorieId,
      categorieNom: categorieNom,
      prixAchat: a.prixAchat,
      prixVente: a.prixVente,
      stockMinimum: a.stockMinimum,
      stockTotal: a.stockTotal,
      dateCreation: a.dateCreation,
      actif: a.actif,
      tauxTvaDefaut: a.tauxTvaDefaut,
      description: a.description,
      marque: a.marque,
      dimension: a.dimension,
      largeur: a.largeur,
      hauteur: a.hauteur,
      diametre: a.diametre,
      type: a.type,
      saison: a.saison,
      etat: a.etat,
      poids: a.poids,
      chargementOrigineId: a.chargementOrigineId,
      chargementOrigineNumero: chargementOrigineNumero,
      prixRevient: await _prixRevientPondere(a.id),
    );
  }

  /// Version liste : ne calcule pas [ArticleEntity.prixRevient] (coûteux,
  /// une requête agrégée par article) — uniquement disponible via
  /// [getArticleById]/[getArticleByCode] pour les vues détail.
  Future<List<ArticleEntity>> _toEntities(List<Article> list) async {
    final cats = await db.articlesDao.getAllCategories();
    final catMap = {for (final c in cats) c.id: c.nom};
    final chargements = await db.loadingsDao.getAllLoadings();
    final chargementMap = {for (final l in chargements) l.id: l.numero};
    return list
        .map((a) => ArticleEntity(
              id: a.id,
              code: a.code,
              nom: a.nom,
              categorieId: a.categorieId,
              categorieNom:
                  a.categorieId != null ? catMap[a.categorieId] : null,
              prixAchat: a.prixAchat,
              prixVente: a.prixVente,
              stockMinimum: a.stockMinimum,
              stockTotal: a.stockTotal,
              dateCreation: a.dateCreation,
              actif: a.actif,
              tauxTvaDefaut: a.tauxTvaDefaut,
              description: a.description,
              marque: a.marque,
              dimension: a.dimension,
              largeur: a.largeur,
              hauteur: a.hauteur,
              diametre: a.diametre,
              type: a.type,
              saison: a.saison,
              etat: a.etat,
              poids: a.poids,
              chargementOrigineId: a.chargementOrigineId,
              chargementOrigineNumero: a.chargementOrigineId != null
                  ? chargementMap[a.chargementOrigineId]
                  : null,
            ))
        .toList();
  }

  @override
  Future<List<ArticleEntity>> getAllArticles() async {
    final articles = await db.articlesDao.getAllArticles();
    return _toEntities(articles);
  }

  @override
  Future<ArticleEntity?> getArticleById(int id) async {
    final a = await db.articlesDao.getArticleById(id);
    if (a == null) return null;
    return _toEntity(a);
  }

  @override
  Future<ArticleEntity?> getArticleByCode(String code) async {
    final a = await db.articlesDao.getArticleByCode(code);
    if (a == null) return null;
    return _toEntity(a);
  }

  @override
  Future<List<ArticleEntity>> searchArticles(String query) async {
    final articles = await db.articlesDao.searchArticles(query);
    return _toEntities(articles);
  }

  @override
  Future<List<ArticleEntity>> getLowStockArticles() async {
    final articles = await db.articlesDao.getLowStockArticles();
    return _toEntities(articles);
  }

  @override
  Future<int> createArticle({
    required String code,
    required String nom,
    int? categorieId,
    required double prixAchat,
    required double prixVente,
    required double stockMinimum,
    String? description,
    String? marque,
    String? dimension,
    double? largeur,
    double? hauteur,
    double? diametre,
    String? type,
    String? saison,
    String etat = 'neuf',
    double? poids,
    int? chargementOrigineId,
  }) {
    return db.articlesDao.createArticle(ArticlesCompanion.insert(
      code: code,
      nom: nom,
      categorieId: Value(categorieId),
      prixAchat: Value(prixAchat),
      prixVente: prixVente,
      stockMinimum: Value(stockMinimum),
      poids: Value(poids),
      description: Value(description),
      marque: Value(marque),
      dimension: Value(dimension),
      largeur: Value(largeur),
      hauteur: Value(hauteur),
      diametre: Value(diametre),
      type: Value(type),
      saison: Value(saison),
      etat: Value(etat),
      chargementOrigineId: Value(chargementOrigineId),
    ));
  }

  @override
  Future<void> updateArticle(ArticleEntity article) async {
    await db.articlesDao.updateArticle(Article(
      id: article.id,
      code: article.code,
      nom: article.nom,
      categorieId: article.categorieId,
      prixAchat: article.prixAchat,
      prixVente: article.prixVente,
      stockMinimum: article.stockMinimum,
      marque: article.marque,
      dimension: article.dimension,
      largeur: article.largeur,
      hauteur: article.hauteur,
      diametre: article.diametre,
      type: article.type,
      saison: article.saison,
      etat: article.etat,
      poids: article.poids,
      chargementOrigineId: article.chargementOrigineId,
      stockTotal: article.stockTotal,
      dateCreation: article.dateCreation,
      actif: article.actif,
      tauxTvaDefaut: 18,
      description: article.description,
    ));
    // Un poids modifié peut changer la répartition "par poids" de
    // dépenses partagées sur des chargements encore ouverts.
    await _recalculerChargementsPourPoids(article.id);
  }

  /// Recalcule les chargements encore ouverts qui ont une dépense
  /// partagée répartie "par poids" et contiennent cet article — un
  /// changement de poids peut changer leur répartition.
  Future<void> _recalculerChargementsPourPoids(int articleId) async {
    final rows = await db.customSelect(
      '''
      SELECT DISTINCT p.chargement_id AS loading_id
      FROM purchase_items pi
      JOIN purchases p ON p.id = pi.purchase_id
      JOIN loadings l ON l.id = p.chargement_id
      WHERE pi.article_id = ? AND p.chargement_id IS NOT NULL AND l.statut = 'ouvert'
        AND EXISTS (
          SELECT 1 FROM expenses e
          WHERE e.chargement_id = p.chargement_id
            AND e.article_id IS NULL
            AND e.methode_allocation = 'poids'
        )
      ''',
      variables: [Variable.withInt(articleId)],
      readsFrom: {db.purchaseItems, db.purchases, db.loadings, db.expenses},
    ).get();
    final service = LoadingCostAllocationService(db);
    for (final r in rows) {
      final loadingId = r.data['loading_id'] as int?;
      if (loadingId != null) await service.recalculer(loadingId);
    }
  }

  @override
  Future<String> genererProchainCodeArticle() =>
      db.articlesDao.genererProchainCode();

  @override
  Future<bool> estArticleUtilise(int id) =>
      db.articlesDao.estArticleUtilise(id);

  @override
  Future<SuppressionArticleResult> supprimerOuArchiverArticle(int id) async {
    final utilise = await db.articlesDao.estArticleUtilise(id);
    if (utilise) {
      // Archivage logique : l'article disparaît des listes et des
      // recherches mais reste dans tous les documents historiques.
      await db.articlesDao.deactivateArticle(id);
      return SuppressionArticleResult.archive;
    } else {
      // Aucun document ne référence cet article : suppression physique.
      await db.articlesDao.deleteArticleDefinitivement(id);
      return SuppressionArticleResult.supprime;
    }
  }

  @override
  @Deprecated('Utiliser supprimerOuArchiverArticle à la place')
  Future<void> deleteArticle(int id) async {
    await db.articlesDao.deactivateArticle(id);
  }

  @override
  Future<double> getStockInStore(int articleId, int storeId) =>
      db.articlesDao.getStockForArticleInStore(articleId, storeId);

  @override
  Future<void> adjustStock({
    required int articleId,
    required int storeId,
    required double delta,
  }) =>
      db.articlesDao
          .adjustStock(articleId: articleId, storeId: storeId, delta: delta);

  @override
  Future<List<ArticleEntity>> getArticlesRecents(int storeId,
      {int limit = 8}) async {
    final rows = await db.customSelect(
      '''
      SELECT dl.article_id AS article_id, MAX(cd.date_creation) AS derniere_vente
      FROM document_lines dl
      JOIN commercial_documents cd ON dl.document_id = cd.id
      WHERE cd.type = 'facture' AND cd.statut != 'annule' AND cd.store_id = ?
      GROUP BY dl.article_id
      ORDER BY derniere_vente DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(storeId), Variable.withInt(limit)],
    ).get();

    final articles = <ArticleEntity>[];
    for (final row in rows) {
      final article = await getArticleById(row.data['article_id'] as int);
      if (article != null && article.actif) articles.add(article);
    }
    return articles;
  }

  @override
  Future<List<CategoryEntity>> getAllCategories() async {
    final cats = await db.articlesDao.getAllCategories();
    return cats.map((c) => CategoryEntity(id: c.id, nom: c.nom)).toList();
  }

  @override
  Future<int> createCategory(String nom) =>
      db.articlesDao.createCategory(CategoriesCompanion.insert(nom: nom));
}
