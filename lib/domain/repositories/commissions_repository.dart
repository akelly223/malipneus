import '../entities/commission.dart';

abstract class CommissionsRepository {
  Future<CommissionConfigEntity?> getConfigForEmployee(int employeeId);

  Future<void> upsertConfig({
    required int employeeId,
    required String typeCommission,
    double? montantFixeParPneu,
    double? pourcentage,
  });

  /// Calcule les commissions dues à un commercial sur une période
  /// librement choisie, à partir des ventes non encore réglées.
  Future<CommissionsDuesEntity> calculerCommissionsDues({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
  });

  /// Règle les commissions dues d'un commercial sur une période :
  /// crée l'enregistrement de règlement et marque toutes les lignes de
  /// vente concernées comme réglées dans la même transaction —
  /// empêche tout double règlement (section 10).
  Future<int> reglerCommissions({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
    required DateTime datePaiement,
    required String modePaiement,
    required int payeParUserId,
    String? payeParUserNom,
    String? notes,
  });

  Future<List<CommissionSettlementEntity>> getSettlementsForEmployee(
      int employeeId);
  Future<List<CommissionSettlementEntity>> getAllSettlements();

  /// Détail vente par vente (client, date, article, montant) des
  /// commissions dues et non encore réglées sur la période — pour
  /// affichage et export PDF de preuve avant règlement.
  Future<List<CommissionLigneDetailEntity>> getDetailCommissionsDues({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
  });

  /// Détail vente par vente d'un règlement déjà effectué — pour
  /// l'export PDF du reçu de paiement (preuve pour le commercial).
  Future<List<CommissionLigneDetailEntity>> getDetailSettlement(
      int settlementId);
}
