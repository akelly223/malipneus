import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/entities/commission.dart';

/// Employés actifs ayant une configuration de commission — les
/// "commerciaux" sélectionnables lors d'une vente comptoir ou pour un
/// règlement de commissions.
final commercialEmployeesProvider =
    FutureProvider.autoDispose<List<EmployeeEntity>>((ref) async {
  final personnelRepo = ref.watch(personnelRepositoryProvider);
  final db = ref.watch(databaseProvider);
  final employeeIds = await db.commissionsDao.getEmployeeIdsAvecConfig();
  final actifs = await personnelRepo.getActiveEmployees();
  return actifs.where((e) => employeeIds.contains(e.id)).toList();
});

final employeeCommissionConfigProvider = FutureProvider.autoDispose
    .family<CommissionConfigEntity?, int>((ref, employeeId) async {
  final repo = ref.watch(commissionsRepositoryProvider);
  return repo.getConfigForEmployee(employeeId);
});

class PeriodeParams {
  final int employeeId;
  final DateTime debut;
  final DateTime fin;

  const PeriodeParams(
      {required this.employeeId, required this.debut, required this.fin});

  @override
  bool operator ==(Object other) =>
      other is PeriodeParams &&
      other.employeeId == employeeId &&
      other.debut == debut &&
      other.fin == fin;

  @override
  int get hashCode => Object.hash(employeeId, debut, fin);
}

final commissionsDuesProvider = FutureProvider.autoDispose
    .family<CommissionsDuesEntity, PeriodeParams>((ref, params) async {
  final repo = ref.watch(commissionsRepositoryProvider);
  return repo.calculerCommissionsDues(
    employeeId: params.employeeId,
    debut: params.debut,
    fin: params.fin,
  );
});

final employeeSettlementsProvider = FutureProvider.autoDispose
    .family<List<CommissionSettlementEntity>, int>((ref, employeeId) async {
  final repo = ref.watch(commissionsRepositoryProvider);
  return repo.getSettlementsForEmployee(employeeId);
});

final allSettlementsProvider =
    FutureProvider.autoDispose<List<CommissionSettlementEntity>>((ref) async {
  final repo = ref.watch(commissionsRepositoryProvider);
  return repo.getAllSettlements();
});

/// Détail vente par vente (client, date, article, montant) des
/// commissions dues et non réglées — pour l'affichage détaillé et
/// l'export PDF de preuve avant règlement.
final commissionsDetailDuesProvider = FutureProvider.autoDispose
    .family<List<CommissionLigneDetailEntity>, PeriodeParams>(
        (ref, params) async {
  final repo = ref.watch(commissionsRepositoryProvider);
  return repo.getDetailCommissionsDues(
    employeeId: params.employeeId,
    debut: params.debut,
    fin: params.fin,
  );
});

/// Détail vente par vente d'un règlement déjà effectué — pour l'export
/// PDF du reçu de paiement remis au commercial.
final settlementDetailProvider = FutureProvider.autoDispose
    .family<List<CommissionLigneDetailEntity>, int>((ref, settlementId) async {
  final repo = ref.watch(commissionsRepositoryProvider);
  return repo.getDetailSettlement(settlementId);
});
