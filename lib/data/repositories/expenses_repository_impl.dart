import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../../core/services/loading_cost_allocation_service.dart';

class ExpensesRepositoryImpl implements ExpensesRepository {
  final AppDatabase db;

  ExpensesRepositoryImpl(this.db);

  Future<ExpenseEntity> _toEntity(
    Expense e,
    Map<int, String> categoriesParId,
    Map<int, String> chargementsParId,
    Map<int, String> articlesParId,
  ) async =>
      ExpenseEntity(
        id: e.id,
        categorieId: e.categorieId,
        categorieNom: categoriesParId[e.categorieId],
        montant: e.montant,
        date: e.date,
        description: e.description,
        fournisseurOuPersonne: e.fournisseurOuPersonne,
        chargementId: e.chargementId,
        chargementNumero:
            e.chargementId != null ? chargementsParId[e.chargementId] : null,
        articleId: e.articleId,
        articleNom: e.articleId != null ? articlesParId[e.articleId] : null,
        methodeAllocation: e.methodeAllocation,
        pieceJustificativePath: e.pieceJustificativePath,
        createdById: e.createdById,
        createdByNom: e.createdByNom,
        dateCreation: e.dateCreation,
      );

  Future<({
    Map<int, String> cats,
    Map<int, String> chargements,
    Map<int, String> articles,
  })> _libelles() async {
    final cats = await db.expensesDao.getAllCategories();
    final chargements = await db.loadingsDao.getAllLoadings();
    final articles = await db.articlesDao.getAllArticles();
    return (
      cats: {for (final c in cats) c.id: c.nom},
      chargements: {for (final l in chargements) l.id: l.numero},
      articles: {for (final a in articles) a.id: a.nom},
    );
  }

  Future<List<ExpenseEntity>> _toEntities(List<Expense> list) async {
    final libelles = await _libelles();
    final result = <ExpenseEntity>[];
    for (final e in list) {
      result.add(await _toEntity(
          e, libelles.cats, libelles.chargements, libelles.articles));
    }
    return result;
  }

  @override
  Future<List<ExpenseCategoryEntity>> getAllCategories() async {
    final rows = await db.expensesDao.getAllCategories();
    return rows
        .map((c) =>
            ExpenseCategoryEntity(id: c.id, nom: c.nom, actif: c.actif))
        .toList();
  }

  @override
  Future<int> createCategory(String nom) => db.expensesDao
      .createCategory(ExpenseCategoriesCompanion.insert(nom: nom));

  @override
  Future<List<ExpenseEntity>> getAllExpenses() async {
    final rows = await db.expensesDao.getAllExpenses();
    return _toEntities(rows);
  }

  @override
  Future<ExpenseEntity?> getExpenseById(int id) async {
    final row = await db.expensesDao.getExpenseById(id);
    if (row == null) return null;
    final libelles = await _libelles();
    return _toEntity(
        row, libelles.cats, libelles.chargements, libelles.articles);
  }

  @override
  Future<List<ExpenseEntity>> getExpensesForLoading(int chargementId) async {
    final rows = await db.expensesDao.getExpensesForLoading(chargementId);
    return _toEntities(rows);
  }

  @override
  Future<List<ExpenseEntity>> getExpensesBetween(
      DateTime debut, DateTime fin) async {
    final rows = await db.expensesDao.getExpensesBetween(debut, fin);
    return _toEntities(rows);
  }

  @override
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
  }) async {
    final id = await db.expensesDao.createExpense(ExpensesCompanion.insert(
      categorieId: categorieId,
      montant: montant,
      date: date,
      description: Value(description),
      fournisseurOuPersonne: Value(fournisseurOuPersonne),
      chargementId: Value(chargementId),
      articleId: Value(articleId),
      methodeAllocation: Value(methodeAllocation),
      pieceJustificativePath: Value(pieceJustificativePath),
      createdById: Value(createdById),
      createdByNom: Value(createdByNom),
    ));
    if (chargementId != null) {
      await LoadingCostAllocationService(db).recalculer(chargementId);
    }
    return id;
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    await db.expensesDao.updateExpense(Expense(
      id: expense.id,
      categorieId: expense.categorieId,
      montant: expense.montant,
      date: expense.date,
      description: expense.description,
      fournisseurOuPersonne: expense.fournisseurOuPersonne,
      chargementId: expense.chargementId,
      articleId: expense.articleId,
      methodeAllocation: expense.methodeAllocation,
      pieceJustificativePath: expense.pieceJustificativePath,
      createdById: expense.createdById,
      createdByNom: expense.createdByNom,
      dateCreation: expense.dateCreation,
    ));
    if (expense.chargementId != null) {
      await LoadingCostAllocationService(db).recalculer(expense.chargementId!);
    }
  }

  @override
  Future<Map<int, double>> getAllocationsManuelles(int expenseId) async {
    final lignes = await db.expensesDao.getAllocationsForExpense(expenseId);
    return {for (final l in lignes) l.purchaseItemId: l.montant};
  }

  @override
  Future<void> setAllocationsManuelles(
    int expenseId,
    Map<int, double> montantsParPurchaseItemId,
  ) async {
    await db.expensesDao.replaceAllocations(
      expenseId,
      montantsParPurchaseItemId.entries
          .where((e) => e.value > 0)
          .map((e) => ExpenseAllocationsCompanion.insert(
                expenseId: expenseId,
                purchaseItemId: e.key,
                montant: e.value,
              ))
          .toList(),
    );
    final expense = await db.expensesDao.getExpenseById(expenseId);
    if (expense?.chargementId != null) {
      await LoadingCostAllocationService(db).recalculer(expense!.chargementId!);
    }
  }
}
