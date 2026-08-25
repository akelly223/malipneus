import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/date_formatter.dart';
import '../../app/providers/repository_providers.dart';
import '../../domain/entities/payroll.dart';
import 'providers/payroll_provider.dart';

class PayrollPeriodsListScreen extends ConsumerWidget {
  const PayrollPeriodsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(payrollPeriodsProvider);
    final settingsAsync = ref.watch(payrollSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paie'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Règle de retenue'),
              onPressed: () =>
                  _ouvrirParametres(context, ref, settingsAsync.value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouvelle période de paie',
              icon: Icons.add_rounded,
              onPressed: () => _ouvrirNouvellePeriode(context, ref),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: periodsAsync.when(
          data: (periods) {
            if (periods.isEmpty) {
              return const EmptyState(
                icon: Icons.calendar_month_outlined,
                message: 'Aucune période de paie créée.',
              );
            }
            return ListView.separated(
              itemCount: periods.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final p = periods[index];
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/payroll/${p.id}'),
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
                                Text(p.libelle, style: AppTextStyles.bodyBold),
                                Text(
                                  '${DateFormatter.formatDate(p.dateDebut)} → '
                                  '${DateFormatter.formatDate(p.dateFin)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }

  Future<void> _ouvrirParametres(BuildContext context, WidgetRef ref,
      PayrollSettingsEntity? settings) async {
    final controller = TextEditingController(
      text: (settings?.joursTheoriquesParMois ?? 30).toStringAsFixed(0),
    );

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Règle de calcul des retenues'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Retenue = salaire de base ÷ jours théoriques par mois × '
                'nombre de jours d\'absence avec retenue.\n\n'
                'Définissez ici le nombre de jours théoriques par mois '
                'utilisé par votre entreprise (souvent 26 ou 30).',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Jours théoriques par mois',
                controller: controller,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler')),
          AppButton(
              label: 'Enregistrer',
              onPressed: () => Navigator.of(dialogContext).pop(true)),
        ],
      ),
    );

    if (confirme == true) {
      final valeur = double.tryParse(controller.text.trim()) ?? 30;
      await ref.read(payrollRepositoryProvider).saveSettings(valeur);
      ref.invalidate(payrollSettingsProvider);
    }
  }

  Future<void> _ouvrirNouvellePeriode(
      BuildContext context, WidgetRef ref) async {
    final libelleController = TextEditingController();
    DateTime dateDebut = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime dateFin =
        DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nouvelle période de paie'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Libellé',
                  controller: libelleController,
                  hint: 'Ex: Août 2026',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: dateDebut,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            locale: const Locale('fr', 'FR'),
                          );
                          if (picked != null) {
                            setDialogState(() => dateDebut = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Début'),
                          child: Text(DateFormatter.formatDate(dateDebut)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: dateFin,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            locale: const Locale('fr', 'FR'),
                          );
                          if (picked != null) {
                            setDialogState(() => dateFin = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fin'),
                          child: Text(DateFormatter.formatDate(dateFin)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler')),
            AppButton(
                label: 'Créer',
                onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        ),
      ),
    );

    if (confirme != true || libelleController.text.trim().isEmpty) return;

    final user = ref.read(sessionProvider);
    final id = await ref.read(payrollRepositoryProvider).createPeriod(
          libelle: libelleController.text.trim(),
          dateDebut: dateDebut,
          dateFin: dateFin,
          createdById: user?.id,
        );
    ref.invalidate(payrollPeriodsProvider);
    if (context.mounted) context.push('/payroll/$id');
  }
}
