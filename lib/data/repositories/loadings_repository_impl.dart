import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/loading.dart';
import '../../domain/repositories/loadings_repository.dart';
import '../../core/constants/db_constants.dart';
import '../../core/services/loading_cost_allocation_service.dart';

class LoadingsRepositoryImpl implements LoadingsRepository {
  final AppDatabase db;

  LoadingsRepositoryImpl(this.db);

  Future<LoadingEntity> _toEntity(Loading l) async {
    final supplier =
        l.supplierId != null ? await db.suppliersDao.getSupplierById(l.supplierId!) : null;
    return LoadingEntity(
      id: l.id,
      numero: l.numero,
      nom: l.nom,
      supplierId: l.supplierId,
      supplierNom: supplier?.nom,
      dateChargement: l.dateChargement,
      dateArrivee: l.dateArrivee,
      container: l.container,
      reference: l.reference,
      notes: l.notes,
      statut: l.statut,
      createdById: l.createdById,
      createdByNom: l.createdByNom,
      dateCreation: l.dateCreation,
    );
  }

  @override
  Future<List<LoadingEntity>> getAllLoadings() async {
    final rows = await db.loadingsDao.getAllLoadings();
    final result = <LoadingEntity>[];
    for (final r in rows) {
      result.add(await _toEntity(r));
    }
    return result;
  }

  @override
  Future<LoadingEntity?> getLoadingById(int id) async {
    final row = await db.loadingsDao.getLoadingById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<int> createLoading({
    String? nom,
    int? supplierId,
    required DateTime dateChargement,
    DateTime? dateArrivee,
    String? container,
    String? reference,
    String? notes,
    int? createdById,
    String? createdByNom,
  }) async {
    final numero = await db.documentCountersDao.genererProchainNumero('CHG');
    return db.loadingsDao.createLoading(LoadingsCompanion.insert(
      numero: numero,
      nom: Value(nom),
      supplierId: Value(supplierId),
      dateChargement: dateChargement,
      dateArrivee: Value(dateArrivee),
      container: Value(container),
      reference: Value(reference),
      notes: Value(notes),
      createdById: Value(createdById),
      createdByNom: Value(createdByNom),
    ));
  }

  @override
  Future<void> updateLoading({
    required int id,
    String? nom,
    int? supplierId,
    required DateTime dateChargement,
    DateTime? dateArrivee,
    String? container,
    String? reference,
    String? notes,
  }) async {
    final row = await db.loadingsDao.getLoadingById(id);
    if (row == null) return;
    await db.loadingsDao.updateLoading(Loading(
      id: row.id,
      numero: row.numero,
      nom: nom,
      supplierId: supplierId,
      dateChargement: dateChargement,
      dateArrivee: dateArrivee,
      container: container,
      reference: reference,
      notes: notes,
      statut: row.statut,
      createdById: row.createdById,
      createdByNom: row.createdByNom,
      dateCreation: row.dateCreation,
    ));
  }

  @override
  Future<void> cloturerLoading(int id) async {
    final row = await db.loadingsDao.getLoadingById(id);
    if (row == null) return;
    await db.loadingsDao.updateLoading(Loading(
      id: row.id,
      numero: row.numero,
      nom: row.nom,
      supplierId: row.supplierId,
      dateChargement: row.dateChargement,
      dateArrivee: row.dateArrivee,
      container: row.container,
      reference: row.reference,
      notes: row.notes,
      statut: 'cloture',
      createdById: row.createdById,
      createdByNom: row.createdByNom,
      dateCreation: row.dateCreation,
    ));
  }

  @override
  Future<void> rouvrirLoading(int id) async {
    final row = await db.loadingsDao.getLoadingById(id);
    if (row == null) return;
    await db.loadingsDao.updateLoading(Loading(
      id: row.id,
      numero: row.numero,
      nom: row.nom,
      supplierId: row.supplierId,
      dateChargement: row.dateChargement,
      dateArrivee: row.dateArrivee,
      container: row.container,
      reference: row.reference,
      notes: row.notes,
      statut: 'ouvert',
      createdById: row.createdById,
      createdByNom: row.createdByNom,
      dateCreation: row.dateCreation,
    ));
  }

  @override
  Future<LoadingRentabiliteEntity> getRentabilite(int loadingId) async {
    // ── Coûts : achats + dépenses imputées ─────────────────────────────────
    final achats = await (db.select(db.purchases)
          ..where((p) => p.chargementId.equals(loadingId)))
        .get();
    final prixAchatTotal =
        achats.fold<double>(0, (s, a) => s + a.totalFinal);

    final depenses = await db.expensesDao.getExpensesForLoading(loadingId);
    final depensesTotal = depenses.fold<double>(0, (s, d) => s + d.montant);

    final coutTotal = prixAchatTotal + depensesTotal;

    // ── Stock : lots reçus pour ce chargement ──────────────────────────────
    final lots = await db.stockLotsDao.getLotsForLoading(loadingId);
    final quantiteRecue =
        lots.fold<double>(0, (s, l) => s + l.quantiteInitiale);
    final quantiteRestante =
        lots.fold<double>(0, (s, l) => s + l.quantiteRestante);

    // ── Consommations de ces lots : ventes, pertes, ajustements ────────────
    final consumptions = await db.stockLotsDao.getConsumptionsForLoading(loadingId);

    double quantiteVendue = 0;
    double pertes = 0;
    double ajustements = 0;
    double coutDesProduitsVendus = 0;
    final documentLineIds = <int>{};
    final movementIds = <int>{};

    for (final c in consumptions) {
      coutDesProduitsVendus += c.quantite * c.coutUnitaireSnapshot;
      if (c.documentLineId != null) {
        quantiteVendue += c.quantite;
        documentLineIds.add(c.documentLineId!);
      } else if (c.movementId != null) {
        movementIds.add(c.movementId!);
      }
    }

    if (movementIds.isNotEmpty) {
      final types =
          await db.stockDao.getTypesPourMouvements(movementIds.toList());
      for (final c in consumptions) {
        if (c.documentLineId != null || c.movementId == null) continue;
        final type = types[c.movementId];
        if (type == DbConstants.movementPerte || type == DbConstants.movementCasse) {
          pertes += c.quantite;
        } else if (type == DbConstants.movementInventaire) {
          ajustements += c.quantite;
        }
      }
    }

    // Prix de revient unitaire = coût total / quantité réellement
    // disponible (reçue - pertes) : les pertes ne sont pas vendables,
    // leur coût doit être réparti sur les unités qui le sont encore.
    final quantiteDisponible = quantiteRecue - pertes;
    final prixRevientUnitaire =
        quantiteDisponible > 0 ? coutTotal / quantiteDisponible : 0.0;

    // ── Ventes : CA, commissions, prix de vente moyen ──────────────────────
    double chiffreAffaires = 0;
    double commissionsCommerciales = 0;
    if (documentLineIds.isNotEmpty) {
      final lignes = await db.commercialDocumentsDao
          .getLignesParIds(documentLineIds.toList());
      for (final l in lignes) {
        chiffreAffaires += l.totalHt;
        commissionsCommerciales += l.commissionMontant ?? 0;
      }
    }
    final prixVenteMoyen =
        quantiteVendue > 0 ? chiffreAffaires / quantiteVendue : 0.0;

    final margeBrute = chiffreAffaires - coutDesProduitsVendus;
    final beneficeEstime = margeBrute - commissionsCommerciales;

    // ── Détail par article (niveau 1) : jamais une moyenne ─────────────────
    final allocation = await LoadingCostAllocationService(db).calculer(loadingId);

    return LoadingRentabiliteEntity(
      loadingId: loadingId,
      quantiteRecue: quantiteRecue,
      quantiteVendue: quantiteVendue,
      quantiteRestante: quantiteRestante,
      pertes: pertes,
      ajustements: ajustements,
      prixAchatTotal: prixAchatTotal,
      depensesTotal: depensesTotal,
      coutTotal: coutTotal,
      prixRevientUnitaire: prixRevientUnitaire,
      chiffreAffaires: chiffreAffaires,
      prixVenteMoyen: prixVenteMoyen,
      coutDesProduitsVendus: coutDesProduitsVendus,
      margeBrute: margeBrute,
      commissionsCommerciales: commissionsCommerciales,
      beneficeEstime: beneficeEstime,
      lignes: allocation.lignes,
      depensesNonAllouees: allocation.depensesNonAllouees,
      erreursAllocation: allocation.erreurs,
    );
  }
}
