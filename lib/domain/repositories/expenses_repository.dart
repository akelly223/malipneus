import '../entities/expense.dart';

abstract class ExpensesRepository {
  Future<List<ExpenseCategoryEntity>> getAllCategories();
  Future<int> createCategory(String nom);

  Future<List<ExpenseEntity>> getAllExpenses();
  Future<ExpenseEntity?> getExpenseById(int id);
  Future<List<ExpenseEntity>> getExpensesForLoading(int chargementId);
  Future<List<ExpenseEntity>> getExpensesBetween(DateTime debut, DateTime fin);

  Future<int> createExpense({
    required int categorieId,
    required double montant,
    required DateTime date,
    String? description,
    String? fournisseurOuPersonne,
    int? chargementId,
    int? articleId,
    String methodeAllocation = 'quantite',
    String? pieceJustificativePath,
    int? createdById,
    String? createdByNom,
  });

  Future<void> updateExpense(ExpenseEntity expense);

  /// Répartition manuelle actuelle d'une dépense : montant attribué par
  /// ligne d'achat (purchaseItemId). Vide si la méthode n'est pas
  /// 'manuelle' ou si rien n'a encore été saisi.
  Future<Map<int, double>> getAllocationsManuelles(int expenseId);

  /// Remplace la répartition manuelle d'une dépense et déclenche le
  /// recalcul du coût de revient du chargement concerné.
  Future<void> setAllocationsManuelles(
    int expenseId,
    Map<int, double> montantsParPurchaseItemId,
  );
}
