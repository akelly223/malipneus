import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/commission.dart';
import '../../domain/repositories/commissions_repository.dart';

class CommissionsRepositoryImpl implements CommissionsRepository {
  final AppDatabase db;

  CommissionsRepositoryImpl(this.db);

  @override
  Future<CommissionConfigEntity?> getConfigForEmployee(int employeeId) async {
    final row = await db.commissionsDao.getConfigForEmployee(employeeId);
    if (row == null) return null;
    return CommissionConfigEntity(
      id: row.id,
      employeeId: row.employeeId,
      typeCommission: row.typeCommission,
      montantFixeParPneu: row.montantFixeParPneu,
      pourcentage: row.pourcentage,
      dateCreation: row.dateCreation,
      dateModification: row.dateModification,
    );
  }

  @override
  Future<void> upsertConfig({
    required int employeeId,
    required String typeCommission,
    double? montantFixeParPneu,
    double? pourcentage,
  }) async {
    final existant = await db.commissionsDao.getConfigForEmployee(employeeId);
    await db.commissionsDao.upsertConfig(CommissionConfigsCompanion(
      id: existant != null ? Value(existant.id) : const Value.absent(),
      employeeId: Value(employeeId),
      typeCommission: Value(typeCommission),
      montantFixeParPneu: Value(montantFixeParPneu),
      pourcentage: Value(pourcentage),
      dateModification: Value(DateTime.now()),
    ));
  }

  /// Lignes de vente non réglées d'un commercial sur la période
  /// [debut, fin], groupées par ligne (une par [TypedResult]).
  Future<List<TypedResult>> _lignesNonReglees({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
  }) =>
      db.commissionsDao.getLignesCommissionABReglerBrutes(
        employeeId: employeeId,
        debut: debut,
        fin: fin,
      );

  ({
    int nombreVentes,
    double quantiteTotale,
    double montantVentesTotal,
    double montantCommission,
  }) _agreger(List<TypedResult> rows) {
    final documentIds = <int>{};
    double quantiteTotale = 0;
    double montantVentesTotal = 0;
    double montantCommission = 0;
    for (final row in rows) {
      final ligne = row.readTable(db.documentLines);
      documentIds.add(ligne.documentId);
      quantiteTotale += ligne.quantite;
      montantVentesTotal += ligne.totalTtc;
      montantCommission += ligne.commissionMontant ?? 0;
    }
    return (
      nombreVentes: documentIds.length,
      quantiteTotale: quantiteTotale,
      montantVentesTotal: montantVentesTotal,
      montantCommission: montantCommission,
    );
  }

  @override
  Future<CommissionsDuesEntity> calculerCommissionsDues({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
  }) async {
    final rows =
        await _lignesNonReglees(employeeId: employeeId, debut: debut, fin: fin);
    final agg = _agreger(rows);
    return CommissionsDuesEntity(
      employeeId: employeeId,
      periodeDebut: debut,
      periodeFin: fin,
      nombreVentes: agg.nombreVentes,
      quantiteTotale: agg.quantiteTotale,
      montantVentesTotal: agg.montantVentesTotal,
      montantCommission: agg.montantCommission,
    );
  }

  @override
  Future<int> reglerCommissions({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
    required DateTime datePaiement,
    required String modePaiement,
    required int payeParUserId,
    String? payeParUserNom,
    String? notes,
  }) async {
    return db.transaction(() async {
      final rows = await _lignesNonReglees(
          employeeId: employeeId, debut: debut, fin: fin);
      final agg = _agreger(rows);

      if (agg.montantCommission <= 0) {
        throw Exception('Aucune commission à régler sur cette période.');
      }

      final settlementId = await db.commissionsDao.createSettlement(
        CommissionSettlementsCompanion.insert(
          employeeId: employeeId,
          periodeDebut: debut,
          periodeFin: fin,
          nombreVentes: Value(agg.nombreVentes),
          quantiteTotale: Value(agg.quantiteTotale),
          montantVentesTotal: Value(agg.montantVentesTotal),
          montantCommission: Value(agg.montantCommission),
          datePaiement: datePaiement,
          modePaiement: Value(modePaiement),
          payeParUserId: payeParUserId,
          payeParUserNom: Value(payeParUserNom),
          notes: Value(notes),
        ),
      );

      // Marque les lignes réglées dans la même transaction : une ligne
      // déjà réglée ne peut plus jamais être sélectionnée par
      // _lignesNonReglees (garde anti double-paiement).
      await db.commissionsDao.marquerLignesReglees(
        employeeId: employeeId,
        debut: debut,
        fin: fin,
        settlementId: settlementId,
      );

      return settlementId;
    });
  }

  Future<CommissionSettlementEntity> _settlementToEntity(
      CommissionSettlement s) async {
    final employee = await db.personnelDao.getEmployeeById(s.employeeId);
    return CommissionSettlementEntity(
      id: s.id,
      employeeId: s.employeeId,
      employeeNomComplet:
          employee != null ? '${employee.prenom} ${employee.nom}' : null,
      periodeDebut: s.periodeDebut,
      periodeFin: s.periodeFin,
      nombreVentes: s.nombreVentes,
      quantiteTotale: s.quantiteTotale,
      montantVentesTotal: s.montantVentesTotal,
      montantCommission: s.montantCommission,
      datePaiement: s.datePaiement,
      modePaiement: s.modePaiement,
      payeParUserId: s.payeParUserId,
      payeParUserNom: s.payeParUserNom,
      dateCreation: s.dateCreation,
      notes: s.notes,
    );
  }

  @override
  Future<List<CommissionSettlementEntity>> getSettlementsForEmployee(
      int employeeId) async {
    final rows = await db.commissionsDao.getSettlementsForEmployee(employeeId);
    final result = <CommissionSettlementEntity>[];
    for (final r in rows) {
      result.add(await _settlementToEntity(r));
    }
    return result;
  }

  @override
  Future<List<CommissionSettlementEntity>> getAllSettlements() async {
    final rows = await db.commissionsDao.getAllSettlements();
    final result = <CommissionSettlementEntity>[];
    for (final r in rows) {
      result.add(await _settlementToEntity(r));
    }
    return result;
  }
}
