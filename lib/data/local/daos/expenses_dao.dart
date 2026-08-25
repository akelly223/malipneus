import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/expense_categories_table.dart';
import '../tables/expenses_table.dart';
import '../tables/expense_allocations_table.dart';

part 'expenses_dao.g.dart';

@DriftAccessor(tables: [ExpenseCategories, Expenses, ExpenseAllocations])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  // ── Catégories ────────────────────────────────────────────────────────────

  Future<List<ExpenseCategory>> getAllCategories() =>
      (select(expenseCategories)..where((c) => c.actif.equals(true))).get();

  Future<int> createCategory(ExpenseCategoriesCompanion category) =>
      into(expenseCategories).insert(category);

  // ── Dépenses ──────────────────────────────────────────────────────────────

  Future<List<Expense>> getAllExpenses() =>
      (select(expenses)..orderBy([(e) => OrderingTerm.desc(e.date)])).get();

  Future<Expense?> getExpenseById(int id) =>
      (select(expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<List<Expense>> getExpensesForLoading(int chargementId) =>
      (select(expenses)..where((e) => e.chargementId.equals(chargementId)))
          .get();

  Future<List<Expense>> getExpensesBetween(DateTime debut, DateTime fin) =>
      (select(expenses)
            ..where((e) =>
                e.date.isBiggerOrEqualValue(debut) &
                e.date.isSmallerOrEqualValue(fin))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .get();

  Future<int> createExpense(ExpensesCompanion expense) =>
      into(expenses).insert(expense);

  Future<bool> updateExpense(Expense expense) =>
      update(expenses).replace(expense);

  // ── Allocations manuelles (méthode 'manuelle') ──────────────────────────

  Future<List<ExpenseAllocation>> getAllocationsForExpense(int expenseId) =>
      (select(expenseAllocations)
            ..where((a) => a.expenseId.equals(expenseId)))
          .get();

  /// Remplace entièrement les lignes d'allocation manuelle d'une dépense
  /// (delete + reinsert, en une transaction).
  Future<void> replaceAllocations(
    int expenseId,
    List<ExpenseAllocationsCompanion> lignes,
  ) {
    return transaction(() async {
      await (delete(expenseAllocations)
            ..where((a) => a.expenseId.equals(expenseId)))
          .go();
      for (final ligne in lignes) {
        await into(expenseAllocations).insert(ligne);
      }
    });
  }
}
