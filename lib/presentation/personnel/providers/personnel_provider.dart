import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/employee.dart';

final jobPositionsProvider =
    FutureProvider.autoDispose<List<JobPositionEntity>>((ref) async {
  final repo = ref.watch(personnelRepositoryProvider);
  return repo.getAllJobPositions();
});

final employeesListProvider =
    FutureProvider.autoDispose<List<EmployeeEntity>>((ref) async {
  final repo = ref.watch(personnelRepositoryProvider);
  return repo.getAllEmployees();
});

final activeEmployeesProvider =
    FutureProvider.autoDispose<List<EmployeeEntity>>((ref) async {
  final repo = ref.watch(personnelRepositoryProvider);
  return repo.getActiveEmployees();
});

final employeeByIdProvider =
    FutureProvider.autoDispose.family<EmployeeEntity?, int>((ref, id) async {
  final repo = ref.watch(personnelRepositoryProvider);
  return repo.getEmployeeById(id);
});

final employeeAbsencesProvider = FutureProvider.autoDispose
    .family<List<EmployeeAbsenceEntity>, int>((ref, employeeId) async {
  final repo = ref.watch(personnelRepositoryProvider);
  return repo.getAbsencesForEmployee(employeeId);
});
