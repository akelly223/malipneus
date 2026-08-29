import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/commission_configs_table.dart';
import '../tables/commission_config_overrides_table.dart';
import '../tables/commission_settlements_table.dart';
import '../tables/document_lines_table.dart';
import '../tables/commercial_documents_table.dart';

part 'commissions_dao.g.dart';

@DriftAccessor(tables: [
  CommissionConfigs,
  CommissionConfigOverrides,
  CommissionSettlements,
  DocumentLines,
  CommercialDocuments,
])
class CommissionsDao extends DatabaseAccessor<AppDatabase>
    with _$CommissionsDaoMixin {
  CommissionsDao(super.db);

  // ── Configuration commerciale ────────────────────────────────────────────

  Future<CommissionConfig?> getConfigForEmployee(int employeeId) =>
      (select(commissionConfigs)
            ..where((c) => c.employeeId.equals(employeeId)))
          .getSingleOrNull();

  Future<List<CommissionConfig>> getAllConfigs() =>
      select(commissionConfigs).get();

  /// Employés actifs ayant une configuration de commission — la liste
  /// des "commerciaux" sélectionnables lors d'une vente comptoir.
  Future<List<int>> getEmployeeIdsAvecConfig() async {
    final rows = await select(commissionConfigs).get();
    return rows.map((c) => c.employeeId).toList();
  }

  Future<int> upsertConfig(CommissionConfigsCompanion config) =>
      into(commissionConfigs).insertOnConflictUpdate(config);

  Future<List<CommissionConfigOverride>> getOverridesForEmployee(
          int employeeId) =>
      (select(commissionConfigOverrides)
            ..where((o) => o.employeeId.equals(employeeId)))
          .get();

  Future<int> createOverride(CommissionConfigOverridesCompanion override) =>
      into(commissionConfigOverrides).insert(override);

  Future<int> deleteOverride(int id) => (delete(commissionConfigOverrides)
        ..where((o) => o.id.equals(id)))
      .go();

  // ── Lignes de vente commissionnées ───────────────────────────────────────

  /// Lignes de vente d'un commercial, non encore réglées, dont le
  /// document est daté dans [debut, fin] (bornes incluses) et dont le
  /// document n'est pas annulé. Utilisé pour calculer le montant dû
  /// avant règlement (section 8/9).
  Future<List<TypedResult>> getLignesCommissionABReglerBrutes({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
  }) {
    final query = select(documentLines).join([
      innerJoin(
        commercialDocuments,
        commercialDocuments.id.equalsExp(documentLines.documentId),
      ),
    ])
      ..where(commercialDocuments.vendeurEmployeeId.equals(employeeId) &
          (commercialDocuments.statut.equals('valide') |
              commercialDocuments.statut.equals('transforme')) &
          commercialDocuments.dateDocument.isBiggerOrEqualValue(debut) &
          commercialDocuments.dateDocument.isSmallerOrEqualValue(fin) &
          documentLines.commissionSettlementId.isNull() &
          documentLines.commissionMontant.isBiggerThanValue(0));
    return query.get();
  }

  /// Marque toutes les lignes correspondantes comme réglées par
  /// [settlementId], dans la transaction appelante — c'est cette
  /// écriture qui garantit qu'une commission n'est jamais réglée deux
  /// fois (une ligne déjà réglée sort du filtre ci-dessus).
  Future<int> marquerLignesReglees({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
    required int settlementId,
  }) async {
    return customUpdate(
      '''
      UPDATE document_lines
      SET commission_settlement_id = ?
      WHERE id IN (
        SELECT dl.id FROM document_lines dl
        JOIN commercial_documents cd ON cd.id = dl.document_id
        WHERE cd.vendeur_employee_id = ?
          AND cd.statut IN ('valide', 'transforme')
          AND cd.date_document >= ?
          AND cd.date_document <= ?
          AND dl.commission_settlement_id IS NULL
          AND dl.commission_montant > 0
      )
      ''',
      variables: [
        Variable.withInt(settlementId),
        Variable.withInt(employeeId),
        Variable.withDateTime(debut),
        Variable.withDateTime(fin),
      ],
      updates: {documentLines, commercialDocuments},
    );
  }

  /// Même filtre que [getLignesCommissionABReglerBrutes], avec en plus
  /// le client de chaque vente (jointure externe, un document peut ne
  /// pas avoir de client enregistré) — pour l'affichage détaillé et
  /// l'export PDF de preuve avant règlement.
  Future<List<TypedResult>> getLignesCommissionDetailNonReglees({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
  }) {
    final query = select(documentLines).join([
      innerJoin(
        commercialDocuments,
        commercialDocuments.id.equalsExp(documentLines.documentId),
      ),
      leftOuterJoin(
        attachedDatabase.clients,
        attachedDatabase.clients.id.equalsExp(commercialDocuments.clientId),
      ),
    ])
      ..where(commercialDocuments.vendeurEmployeeId.equals(employeeId) &
          (commercialDocuments.statut.equals('valide') |
              commercialDocuments.statut.equals('transforme')) &
          commercialDocuments.dateDocument.isBiggerOrEqualValue(debut) &
          commercialDocuments.dateDocument.isSmallerOrEqualValue(fin) &
          documentLines.commissionSettlementId.isNull() &
          documentLines.commissionMontant.isBiggerThanValue(0))
      ..orderBy([OrderingTerm.asc(commercialDocuments.dateDocument)]);
    return query.get();
  }

  /// Détail (avec client) des lignes réglées par [settlementId] — pour
  /// l'export PDF du reçu de règlement remis au commercial.
  Future<List<TypedResult>> getLignesCommissionDetailPourSettlement(
      int settlementId) {
    final query = select(documentLines).join([
      innerJoin(
        commercialDocuments,
        commercialDocuments.id.equalsExp(documentLines.documentId),
      ),
      leftOuterJoin(
        attachedDatabase.clients,
        attachedDatabase.clients.id.equalsExp(commercialDocuments.clientId),
      ),
    ])
      ..where(documentLines.commissionSettlementId.equals(settlementId))
      ..orderBy([OrderingTerm.asc(commercialDocuments.dateDocument)]);
    return query.get();
  }

  Future<int> createSettlement(CommissionSettlementsCompanion settlement) =>
      into(commissionSettlements).insert(settlement);

  Future<List<CommissionSettlement>> getSettlementsForEmployee(
          int employeeId) =>
      (select(commissionSettlements)
            ..where((s) => s.employeeId.equals(employeeId))
            ..orderBy([(s) => OrderingTerm.desc(s.dateCreation)]))
          .get();

  Future<List<CommissionSettlement>> getAllSettlements() =>
      (select(commissionSettlements)
            ..orderBy([(s) => OrderingTerm.desc(s.dateCreation)]))
          .get();
}
