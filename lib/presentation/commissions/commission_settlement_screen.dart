import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/commission.dart';
import 'providers/commissions_provider.dart';

/// Module Règlement des commissions (sections 8/9).
///
/// Le responsable choisit librement un commercial et une période, voit
/// le montant dû calculé en direct depuis les ventes non réglées, et
/// peut régler — ce qui marque ces ventes comme réglées pour toujours
/// (garde anti double-paiement, voir CommissionsRepositoryImpl).
class CommissionSettlementScreen extends ConsumerStatefulWidget {
  const CommissionSettlementScreen({super.key});

  @override
  ConsumerState<CommissionSettlementScreen> createState() =>
      _CommissionSettlementScreenState();
}

class _CommissionSettlementScreenState
    extends ConsumerState<CommissionSettlementScreen> {
  int? _employeeId;
  DateTime _debut = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fin = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final commerciauxAsync = ref.watch(commercialEmployeesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Règlement des commissions')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: commerciauxAsync.when(
                data: (commerciaux) {
                  if (commerciaux.isEmpty) {
                    return const Text(
                      'Aucun commercial configuré. Ouvrez la fiche d\'un '
                      'employé (module Personnel) pour lui définir une '
                      'commission.',
                      style: AppTextStyles.body,
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _employeeId,
                          decoration: const InputDecoration(
                              labelText: 'Commercial'),
                          items: commerciaux
                              .map((e) => DropdownMenuItem(
                                  value: e.id, child: Text(e.nomComplet)))
                              .toList(),
                          onChanged: (v) => setState(() => _employeeId = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _debut,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              locale: const Locale('fr', 'FR'),
                            );
                            if (picked != null) {
                              setState(() => _debut = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration:
                                const InputDecoration(labelText: 'Début'),
                            child: Text(DateFormatter.formatDate(_debut)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fin,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              locale: const Locale('fr', 'FR'),
                            );
                            if (picked != null) {
                              setState(() => _fin = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Fin'),
                            child: Text(DateFormatter.formatDate(_fin)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erreur: $e'),
              ),
            ),
            const SizedBox(height: 24),
            if (_employeeId != null)
              _DueAmountCard(
                employeeId: _employeeId!,
                debut: _debut,
                fin: _fin,
                onRegle: () => setState(() {}),
              ),
            const SizedBox(height: 24),
            const Text('Historique des règlements', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            Expanded(
              child: _employeeId == null
                  ? _AllSettlementsHistory()
                  : _EmployeeSettlementsHistory(employeeId: _employeeId!),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueAmountCard extends ConsumerWidget {
  final int employeeId;
  final DateTime debut;
  final DateTime fin;
  final VoidCallback onRegle;

  const _DueAmountCard({
    required this.employeeId,
    required this.debut,
    required this.fin,
    required this.onRegle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params =
        PeriodeParams(employeeId: employeeId, debut: debut, fin: fin);
    final dueAsync = ref.watch(commissionsDuesProvider(params));

    return dueAsync.when(
      data: (due) {
        final estNonRegle = due.montantCommission > 0.01;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: estNonRegle ? AppColors.warning : AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${due.nombreVentes} vente(s) — '
                        '${due.quantiteTotale.toStringAsFixed(0)} article(s)'),
                    const SizedBox(height: 4),
                    Text(
                      'Commission due : '
                      '${CurrencyFormatter.format(due.montantCommission)}',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 18),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (estNonRegle
                                ? AppColors.warning
                                : AppColors.success)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        estNonRegle ? 'NON RÉGLÉ' : 'RIEN À RÉGLER',
                        style: TextStyle(
                          color: estNonRegle
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (estNonRegle)
                AppButton(
                  label: 'Régler',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () => _regler(context, ref, due),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur: $e'),
    );
  }

  Future<void> _regler(
      BuildContext context, WidgetRef ref, CommissionsDuesEntity due) async {
    String modePaiement = 'especes';
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Confirmer le règlement'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Régler ${CurrencyFormatter.format(due.montantCommission)} '
                  'pour la période ${DateFormatter.formatDate(debut)} → '
                  '${DateFormatter.formatDate(fin)} ?',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: modePaiement,
                  decoration: const InputDecoration(labelText: 'Mode de paiement'),
                  items: const [
                    DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                    DropdownMenuItem(
                        value: 'orange_money', child: Text('Orange Money')),
                    DropdownMenuItem(
                        value: 'moov_money', child: Text('Moov Money')),
                    DropdownMenuItem(value: 'virement', child: Text('Virement')),
                    DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => modePaiement = v ?? 'especes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler')),
            AppButton(
                label: 'Confirmer',
                onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        ),
      ),
    );

    if (confirme != true) return;
    final user = ref.read(sessionProvider);
    if (user == null) return;

    await ref.read(commissionsRepositoryProvider).reglerCommissions(
          employeeId: employeeId,
          debut: debut,
          fin: fin,
          datePaiement: DateTime.now(),
          modePaiement: modePaiement,
          payeParUserId: user.id,
          payeParUserNom: user.nom,
        );

    ref.invalidate(commissionsDuesProvider(
        PeriodeParams(employeeId: employeeId, debut: debut, fin: fin)));
    ref.invalidate(employeeSettlementsProvider(employeeId));
    ref.invalidate(allSettlementsProvider);
    onRegle();
  }
}

class _EmployeeSettlementsHistory extends ConsumerWidget {
  final int employeeId;
  const _EmployeeSettlementsHistory({required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsAsync = ref.watch(employeeSettlementsProvider(employeeId));
    return settlementsAsync.when(
      data: (settlements) => _list(settlements),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur: $e'),
    );
  }

  Widget _list(List<CommissionSettlementEntity> settlements) {
    if (settlements.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        message: 'Aucun règlement enregistré pour ce commercial.',
      );
    }
    return ListView.separated(
      itemCount: settlements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _SettlementTile(settlement: settlements[i]),
    );
  }
}

class _AllSettlementsHistory extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsAsync = ref.watch(allSettlementsProvider);
    return settlementsAsync.when(
      data: (settlements) {
        if (settlements.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            message: 'Aucun règlement de commission enregistré.',
          );
        }
        return ListView.separated(
          itemCount: settlements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _SettlementTile(settlement: settlements[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur: $e'),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  final CommissionSettlementEntity settlement;
  const _SettlementTile({required this.settlement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(settlement.employeeNomComplet ?? '—',
                    style: AppTextStyles.bodyBold),
                Text(
                  '${DateFormatter.formatDate(settlement.periodeDebut)} → '
                  '${DateFormatter.formatDate(settlement.periodeFin)} · '
                  '${settlement.nombreVentes} vente(s)',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.format(settlement.montantCommission),
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.success)),
              Text(DateFormatter.formatDate(settlement.datePaiement),
                  style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}
