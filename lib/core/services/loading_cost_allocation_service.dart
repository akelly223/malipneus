import 'package:drift/drift.dart';
import '../../data/local/database.dart';
import '../../domain/entities/loading.dart';

/// Ligne d'achat brute d'un chargement, avant répartition des dépenses.
class _LigneBrute {
  final int purchaseItemId;
  final int articleId;
  final double quantite;
  final double prixAchatUnitaire;
  final double totalLigne;

  const _LigneBrute({
    required this.purchaseItemId,
    required this.articleId,
    required this.quantite,
    required this.prixAchatUnitaire,
    required this.totalLigne,
  });
}

/// Résultat du calcul de répartition d'un chargement : le détail par
/// ligne d'achat, plus ce qui n'a pas pu être réparti (voir
/// [LoadingRentabiliteEntity.depensesNonAllouees]/[erreursAllocation]).
class AllocationResult {
  final List<ArticleRentabiliteLigne> lignes;
  final double depensesNonAllouees;
  final List<String> erreurs;

  const AllocationResult({
    required this.lignes,
    required this.depensesNonAllouees,
    required this.erreurs,
  });
}

/// Calcule et persiste le COÛT DE REVIENT RÉEL PAR ARTICLE d'un
/// chargement — jamais une moyenne globale.
///
/// Principe : l'unité de répartition est la LIGNE D'ACHAT (donc le lot
/// de stock qu'elle a créé), pas l'article abstrait — un même article
/// acheté deux fois à des prix différents dans le même chargement garde
/// deux coûts distincts.
///
/// [calculer] est la SEULE implémentation de l'algorithme de
/// répartition : utilisée à la fois par [recalculer] (écriture, persiste
/// dans `stock_lots.coutUnitaire` via le code déjà présent mais jamais
/// appelé avant cette fonctionnalité, `StockLotsDao.mettreAJourCoutUnitaire`)
/// et par `LoadingsRepositoryImpl.getRentabilite` (lecture) — pour que
/// les deux ne divergent jamais.
class LoadingCostAllocationService {
  final AppDatabase db;

  LoadingCostAllocationService(this.db);

  Future<AllocationResult> calculer(int loadingId) async {
    // ── 1. Lignes d'achat du chargement ─────────────────────────────────
    final rows = await db.customSelect(
      '''
      SELECT pi.id AS item_id, pi.article_id, pi.quantite,
             pi.prix_achat_unitaire, pi.total_ligne
      FROM purchase_items pi
      JOIN purchases p ON p.id = pi.purchase_id
      WHERE p.chargement_id = ?
      ''',
      variables: [Variable.withInt(loadingId)],
      readsFrom: {db.purchaseItems, db.purchases},
    ).get();

    if (rows.isEmpty) {
      return const AllocationResult(lignes: [], depensesNonAllouees: 0, erreurs: []);
    }

    final lignesBrutes = rows
        .map((r) => _LigneBrute(
              purchaseItemId: r.data['item_id'] as int,
              articleId: r.data['article_id'] as int,
              quantite: (r.data['quantite'] as num).toDouble(),
              prixAchatUnitaire: (r.data['prix_achat_unitaire'] as num).toDouble(),
              totalLigne: (r.data['total_ligne'] as num).toDouble(),
            ))
        .toList();

    final quantiteTotaleChargement =
        lignesBrutes.fold<double>(0, (s, l) => s + l.quantite);
    final valeurTotaleChargement =
        lignesBrutes.fold<double>(0, (s, l) => s + l.totalLigne);

    final quantiteParArticle = <int, double>{};
    for (final l in lignesBrutes) {
      quantiteParArticle[l.articleId] =
          (quantiteParArticle[l.articleId] ?? 0) + l.quantite;
    }

    // ── 2. Dépenses directes vs partagées ────────────────────────────────
    final depenses = await db.expensesDao.getExpensesForLoading(loadingId);
    final directes = depenses.where((e) => e.articleId != null).toList();
    final partagees = depenses.where((e) => e.articleId == null).toList();

    double depensesNonAllouees = 0;
    final erreurs = <String>[];

    // Dépense directe : répartie également entre les lignes de CE
    // même article dans ce chargement (dénominateur = quantité totale
    // de cet article dans ce chargement, pas toutes ses lignes ailleurs).
    final directParArticle = <int, double>{};
    for (final d in directes) {
      final qteArticle = quantiteParArticle[d.articleId!];
      if (qteArticle == null || qteArticle <= 0) {
        // Article visé sans aucune ligne d'achat dans ce chargement :
        // rien à quoi l'attribuer — compté globalement, absent du détail.
        depensesNonAllouees += d.montant;
        continue;
      }
      directParArticle[d.articleId!] = (directParArticle[d.articleId!] ?? 0) + d.montant;
    }

    // Poids (chargé seulement si une dépense "poids" existe).
    final articlesMap = {for (final a in await db.articlesDao.getAllArticles()) a.id: a};
    final besoinPoids = partagees.any((e) => e.methodeAllocation == 'poids');
    Map<int, double?> poidsParArticle = {};
    if (besoinPoids) {
      for (final id in quantiteParArticle.keys) {
        poidsParArticle[id] = articlesMap[id]?.poids;
      }
    }

    // Allocations manuelles.
    final manuelParExpense = <int, Map<int, double>>{};
    for (final e in partagees.where((e) => e.methodeAllocation == 'manuelle')) {
      final lignesManuelles = await db.expensesDao.getAllocationsForExpense(e.id);
      manuelParExpense[e.id] = {
        for (final l in lignesManuelles) l.purchaseItemId: l.montant,
      };
    }

    // ── 3. Part partagée par ligne d'achat, selon la méthode choisie ────
    final sharedShare = <int, double>{}; // purchaseItemId -> montant

    for (final e in partagees) {
      switch (e.methodeAllocation) {
        case 'valeur_achat':
          if (valeurTotaleChargement <= 0) {
            depensesNonAllouees += e.montant;
            continue;
          }
          for (final l in lignesBrutes) {
            final part = e.montant * l.totalLigne / valeurTotaleChargement;
            sharedShare[l.purchaseItemId] = (sharedShare[l.purchaseItemId] ?? 0) + part;
          }
          break;

        case 'poids':
          final articlesSansPoids = lignesBrutes
              .map((l) => l.articleId)
              .toSet()
              .where((id) => poidsParArticle[id] == null)
              .map((id) => articlesMap[id]?.nom ?? 'article #$id')
              .toList();
          if (articlesSansPoids.isNotEmpty) {
            erreurs.add(
              'Répartition par poids impossible pour la dépense '
              '"${e.description ?? e.categorieId}" (${e.montant.toStringAsFixed(0)} F) : '
              'poids manquant pour ${articlesSansPoids.join(', ')}.',
            );
            depensesNonAllouees += e.montant;
            continue;
          }
          final poidsTotal = lignesBrutes.fold<double>(
              0, (s, l) => s + l.quantite * (poidsParArticle[l.articleId] ?? 0));
          if (poidsTotal <= 0) {
            depensesNonAllouees += e.montant;
            continue;
          }
          for (final l in lignesBrutes) {
            final poidsLigne = l.quantite * (poidsParArticle[l.articleId] ?? 0);
            final part = e.montant * poidsLigne / poidsTotal;
            sharedShare[l.purchaseItemId] = (sharedShare[l.purchaseItemId] ?? 0) + part;
          }
          break;

        case 'manuelle':
          final table = manuelParExpense[e.id] ?? const {};
          final alloue = table.values.fold<double>(0, (s, v) => s + v);
          if (alloue < e.montant - 0.01) {
            depensesNonAllouees += (e.montant - alloue);
            erreurs.add(
              'Répartition manuelle incomplète pour la dépense '
              '"${e.description ?? e.categorieId}" : '
              '${(e.montant - alloue).toStringAsFixed(0)} F non attribué(s).',
            );
          }
          for (final l in lignesBrutes) {
            final montant = table[l.purchaseItemId] ?? 0;
            if (montant > 0) {
              sharedShare[l.purchaseItemId] =
                  (sharedShare[l.purchaseItemId] ?? 0) + montant;
            }
          }
          break;

        case 'quantite':
        default:
          if (quantiteTotaleChargement <= 0) {
            depensesNonAllouees += e.montant;
            continue;
          }
          for (final l in lignesBrutes) {
            final part = e.montant * l.quantite / quantiteTotaleChargement;
            sharedShare[l.purchaseItemId] = (sharedShare[l.purchaseItemId] ?? 0) + part;
          }
      }
    }

    // ── 4. Assemblage final ligne par ligne ─────────────────────────────
    final lignes = <ArticleRentabiliteLigne>[];
    for (final l in lignesBrutes) {
      final directArticleTotal = directParArticle[l.articleId];
      final directLigne = directArticleTotal != null
          ? directArticleTotal * l.quantite / (quantiteParArticle[l.articleId] ?? l.quantite)
          : 0.0;
      final sharedLigne = sharedShare[l.purchaseItemId] ?? 0;
      final partDepensesTotal = directLigne + sharedLigne;
      final partDepensesUnitaire = l.quantite > 0 ? partDepensesTotal / l.quantite : 0.0;
      final coutRevientUnitaire = l.prixAchatUnitaire + partDepensesUnitaire;
      final article = articlesMap[l.articleId];
      final prixVenteUnitaire = article?.prixVente ?? 0.0;
      final margeUnitaire = prixVenteUnitaire - coutRevientUnitaire;

      lignes.add(ArticleRentabiliteLigne(
        purchaseItemId: l.purchaseItemId,
        articleId: l.articleId,
        articleNom: article?.nom ?? '???',
        quantite: l.quantite,
        prixAchatUnitaire: l.prixAchatUnitaire,
        partDepensesUnitaire: partDepensesUnitaire,
        coutRevientUnitaire: coutRevientUnitaire,
        prixVenteUnitaire: prixVenteUnitaire,
        margeUnitaire: margeUnitaire,
        margeTotale: margeUnitaire * l.quantite,
      ));
    }

    return AllocationResult(
      lignes: lignes,
      depensesNonAllouees: depensesNonAllouees,
      erreurs: erreurs,
    );
  }

  /// Recalcule et PERSISTE le coût de revient réel dans
  /// `stock_lots.coutUnitaire` pour les lots encore ouverts (reliquat >
  /// 0) de ce chargement. Ne touche jamais les consommations déjà
  /// enregistrées (`StockLotConsumptions.coutUnitaireSnapshot`, figées
  /// au moment de la vente/perte — cohérence FIFO).
  ///
  /// Sans effet si le chargement est "cloturé" (coût figé), sauf
  /// [forcer] explicite (ex: réouverture manuelle par un admin).
  Future<void> recalculer(int loadingId, {bool forcer = false}) async {
    final loading = await db.loadingsDao.getLoadingById(loadingId);
    if (loading == null) return;
    if (loading.statut == 'cloture' && !forcer) return;

    final result = await calculer(loadingId);
    if (result.lignes.isEmpty) return;

    await db.transaction(() async {
      for (final ligne in result.lignes) {
        final lots = await db.stockLotsDao.getLotsByPurchaseItem(ligne.purchaseItemId);
        for (final lot in lots) {
          if (lot.quantiteRestante <= 0) continue;
          await db.stockLotsDao.mettreAJourCoutUnitaire(lot.id, ligne.coutRevientUnitaire);
        }
      }
    });
  }
}
