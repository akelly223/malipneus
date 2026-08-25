import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/payroll.dart';

final payrollSettingsProvider =
    FutureProvider.autoDispose<PayrollSettingsEntity>((ref) async {
  final repo = ref.watch(payrollRepositoryProvider);
  return repo.getSettings();
});

final payrollPeriodsProvider =
    FutureProvider.autoDispose<List<PayrollPeriodEntity>>((ref) async {
  final repo = ref.watch(payrollRepositoryProvider);
  return repo.getAllPeriods();
});

final payrollPeriodByIdProvider = FutureProvider.autoDispose
    .family<PayrollPeriodEntity?, int>((ref, id) async {
  final repo = ref.watch(payrollRepositoryProvider);
  return repo.getPeriodById(id);
});

final payslipsForPeriodProvider = FutureProvider.autoDispose
    .family<List<PayslipEntity>, int>((ref, periodId) async {
  final repo = ref.watch(payrollRepositoryProvider);
  return repo.getPayslipsForPeriod(periodId);
});

final payslipByIdProvider =
    FutureProvider.autoDispose.family<PayslipEntity?, int>((ref, id) async {
  final repo = ref.watch(payrollRepositoryProvider);
  return repo.getPayslipById(id);
});

final payslipPaymentsProvider = FutureProvider.autoDispose
    .family<List<PayslipPaymentEntity>, int>((ref, payslipId) async {
  final repo = ref.watch(payrollRepositoryProvider);
  return repo.getPaymentsForPayslip(payslipId);
});

final employeeAdvancesProvider = FutureProvider.autoDispose
    .family<List<SalaryAdvanceEntity>, int>((ref, employeeId) async {
  final repo = ref.watch(payrollRepositoryProvider);
  return repo.getAdvancesForEmployee(employeeId);
});
