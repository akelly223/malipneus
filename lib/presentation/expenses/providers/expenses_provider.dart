import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/expense.dart';

final expenseCategoriesProvider =
    FutureProvider.autoDispose<List<ExpenseCategoryEntity>>((ref) async {
  final repo = ref.watch(expensesRepositoryProvider);
  return repo.getAllCategories();
});

final expensesListProvider =
    FutureProvider.autoDispose<List<ExpenseEntity>>((ref) async {
  final repo = ref.watch(expensesRepositoryProvider);
  return repo.getAllExpenses();
});

final expensesForLoadingProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntity>, int>((ref, chargementId) async {
  final repo = ref.watch(expensesRepositoryProvider);
  return repo.getExpensesForLoading(chargementId);
});
