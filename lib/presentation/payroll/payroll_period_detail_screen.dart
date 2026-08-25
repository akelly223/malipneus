import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/entities/payroll.dart';
import 'providers/payroll_provider.dart';

class PayrollPeriodDetailScreen extends ConsumerWidget {
  final int periodId;
  const PayrollPeriodDetailScreen({super.key, required this.periodId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodAsync = ref.watch(payrollPeriodByIdProvider(periodId));
    final payslipsAsync = ref.watch(payslipsForPeriodProvider(periodId));

    return Scaffold(
      appBar: AppBar(
        title: periodAsync.when(
          data: (p) => Text(p?.libelle ?? 'Période de paie'),
          loading: () => const Text('Période de paie'),
          error: (_, __) => const Text('Période de paie'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Générer les bulletins',
              icon: Icons.receipt_long_rounded,
              onPressed: () async {
                try {
                  await ref
                      .read(payrollRepositoryProvider)
                      .genererBulletinsPourPeriode(periodId);
                  ref.invalidate(payslipsForPeriodProvider(periodId));
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: payslipsAsync.when(
          data: (payslips) {
            if (payslips.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Aucun bulletin. Cliquez sur "Générer les '
                    'bulletins" pour créer ceux des employés actifs.',
              );
            }
            final totalNet =
                payslips.fold<double>(0, (s, p) => s + p.salaireNet);
            final totalPaye =
                payslips.fold<double>(0, (s, p) => s + p.montantPaye);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                        '${payslips.length} bulletin(s) — '
                        '${CurrencyFormatter.format(totalNet)} net, '
                        '${CurrencyFormatter.format(totalNet - totalPaye)} '
                        'restant à payer',
                        style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: payslips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _PayslipTile(payslip: payslips[index]),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }
}

class _PayslipTile extends StatelessWidget {
  final PayslipEntity payslip;
  const _PayslipTile({required this.payslip});

  @override
  Widget build(BuildContext context) {
    final Color statutColor = switch (payslip.statutPaiement) {
      'paye' => AppColors.success,
      'partiel' => AppColors.warning,
      _ => AppColors.danger,
    };
    final String statutLabel = switch (payslip.statutPaiement) {
      'paye' => 'Payé',
      'partiel' => 'Partiel',
      _ => 'Non payé',
    };

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/payroll/payslip/${payslip.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payslip.employeeNomComplet ?? '—',
                        style: AppTextStyles.bodyBold),
                    Text(
                      'Net: ${CurrencyFormatter.format(payslip.salaireNet)}'
                      '${payslip.retenueAbsence > 0 ? ' · retenue ${CurrencyFormatter.format(payslip.retenueAbsence)}' : ''}'
                      '${payslip.avancesDeduites > 0 ? ' · avances ${CurrencyFormatter.format(payslip.avancesDeduites)}' : ''}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statutColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statutLabel,
                    style: TextStyle(
                        color: statutColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
