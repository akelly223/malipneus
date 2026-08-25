import 'package:drift/drift.dart';
import 'expenses_table.dart';
import 'purchases_table.dart';

/// Répartition MANUELLE d'une dépense partagée entre les lignes d'achat
/// d'un chargement — source de vérité uniquement quand
/// [Expenses.methodeAllocation] vaut 'manuelle' (pour les autres
/// méthodes, la répartition est recalculée à la volée, jamais mise en
/// cache ici, voir LoadingCostAllocationService).
class ExpenseAllocations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get expenseId => integer().references(Expenses, #id)();
  IntColumn get purchaseItemId =>
      integer().references(PurchaseItems, #id)();

  RealColumn get montant => real()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {expenseId, purchaseItemId},
      ];
}
