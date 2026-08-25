import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/entities/employee.dart';
import '../payroll/providers/payroll_provider.dart';
import '../commissions/providers/commissions_provider.dart';
import '../../domain/entities/commission.dart';
import 'providers/personnel_provider.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  final int employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeAsync = ref.watch(employeeByIdProvider(employeeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche employé')),
      body: employeeAsync.when(
        data: (employee) {
          if (employee == null) {
            return const Center(child: Text('Employé introuvable.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FicheCard(employee: employee),
                const SizedBox(height: 24),
                _AbsencesSection(employee: employee),
                const SizedBox(height: 24),
                _AdvancesSection(employee: employee),
                const SizedBox(height: 24),
                _CommissionConfigSection(employee: employee),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

class _FicheCard extends ConsumerWidget {
  final EmployeeEntity employee;
  const _FicheCard({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(employee.nomComplet, style: AppTextStyles.h3),
              ),
              if (employee.estActif)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Actif',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                )
              else
                TextButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.person_off_outlined,
                      color: AppColors.danger),
                  label: const Text('Inactif',
                      style: TextStyle(color: AppColors.danger)),
                ),
              if (employee.estActif)
                IconButton(
                  tooltip: 'Marquer comme parti',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => _confirmerDepart(context, ref, employee),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ligne('Poste', employee.posteNom ?? '—'),
          _ligne('Téléphone', employee.telephone ?? '—'),
          _ligne('Date d\'embauche',
              DateFormatter.formatDate(employee.dateEmbauche)),
          _ligne('Type de contrat', employee.typeContrat ?? '—'),
          _ligne('Salaire de base',
              CurrencyFormatter.format(employee.salaireBase)),
          if (employee.dateDepart != null)
            _ligne('Date de départ',
                DateFormatter.formatDate(employee.dateDepart!)),
          if (employee.notes != null && employee.notes!.isNotEmpty)
            _ligne('Notes', employee.notes!),
        ],
      ),
    );
  }

  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 150,
                child: Text(label, style: AppTextStyles.caption)),
            Expanded(child: Text(valeur, style: AppTextStyles.body)),
          ],
        ),
      );

  Future<void> _confirmerDepart(
      BuildContext context, WidgetRef ref, EmployeeEntity employee) async {
    DateTime dateDepart = DateTime.now();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Marquer le départ de l\'employé'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Confirmer le départ de ${employee.nomComplet} ? '
                    'L\'employé passera au statut "inactif".',
                    style: AppTextStyles.body),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: dateDepart,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (picked != null) {
                      setDialogState(() => dateDepart = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Date de départ'),
                    child: Text(DateFormatter.formatDate(dateDepart)),
                  ),
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
              isDanger: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      ),
    );

    if (confirme == true) {
      final repo = ref.read(personnelRepositoryProvider);
      await repo.deactivateEmployee(employee.id, dateDepart);
      ref.invalidate(employeeByIdProvider(employee.id));
      ref.invalidate(employeesListProvider);
      ref.invalidate(activeEmployeesProvider);
    }
  }
}

class _AbsencesSection extends ConsumerWidget {
  final EmployeeEntity employee;
  const _AbsencesSection({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absencesAsync = ref.watch(employeeAbsencesProvider(employee.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Absences', style: AppTextStyles.h3)),
            AppButton(
              label: 'Enregistrer une absence',
              icon: Icons.event_busy_rounded,
              onPressed: () =>
                  _ouvrirFormulaireAbsence(context, ref, employee),
            ),
          ],
        ),
        const SizedBox(height: 12),
        absencesAsync.when(
          data: (absences) {
            if (absences.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available_rounded,
                message: 'Aucune absence enregistrée.',
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: absences.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final a = absences[index];
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
                            Text(
                              '${DateFormatter.formatDate(a.dateDebut)} → '
                              '${DateFormatter.formatDate(a.dateFin)} '
                              '(${a.nombreJours.toStringAsFixed(a.nombreJours.truncateToDouble() == a.nombreJours ? 0 : 1)} j)',
                              style: AppTextStyles.bodyBold,
                            ),
                            Text(a.motif, style: AppTextStyles.caption),
                            if (a.commentaire != null &&
                                a.commentaire!.isNotEmpty)
                              Text(a.commentaire!,
                                  style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      _badge(a.justifiee ? 'Justifiée' : 'Non justifiée',
                          a.justifiee ? AppColors.success : AppColors.warning),
                      const SizedBox(width: 8),
                      _badge(
                          a.avecRetenue ? 'Avec retenue' : 'Sans retenue',
                          a.avecRetenue
                              ? AppColors.danger
                              : AppColors.textSecondary),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
        ),
      ],
    );
  }

  Widget _badge(String texte, Color couleur) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: couleur.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(texte,
            style: TextStyle(
                color: couleur, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Future<void> _ouvrirFormulaireAbsence(
      BuildContext context, WidgetRef ref, EmployeeEntity employee) async {
    DateTime dateDebut = DateTime.now();
    DateTime dateFin = DateTime.now();
    final motifController = TextEditingController();
    final joursController = TextEditingController(text: '1');
    final commentaireController = TextEditingController();
    bool justifiee = true;
    bool avecRetenue = true;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nouvelle absence'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                            decoration: const InputDecoration(
                                labelText: 'Date de début'),
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
                            decoration:
                                const InputDecoration(labelText: 'Date de fin'),
                            child: Text(DateFormatter.formatDate(dateFin)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Nombre de jours',
                    controller: joursController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Motif', controller: motifController),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Commentaire',
                    controller: commentaireController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Absence justifiée'),
                    value: justifiee,
                    onChanged: (v) => setDialogState(() => justifiee = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Avec retenue sur salaire'),
                    value: avecRetenue,
                    onChanged: (v) => setDialogState(() => avecRetenue = v),
                  ),
                ],
              ),
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
      ),
    );

    if (confirme != true) return;
    if (motifController.text.trim().isEmpty) return;

    final user = ref.read(sessionProvider);
    if (user == null) return;

    final repo = ref.read(personnelRepositoryProvider);
    await repo.createAbsence(
      employeeId: employee.id,
      dateDebut: dateDebut,
      dateFin: dateFin,
      nombreJours: double.tryParse(joursController.text.trim()) ?? 1,
      motif: motifController.text.trim(),
      justifiee: justifiee,
      avecRetenue: avecRetenue,
      commentaire: commentaireController.text.trim().isEmpty
          ? null
          : commentaireController.text.trim(),
      userId: user.id,
    );

    ref.invalidate(employeeAbsencesProvider(employee.id));
  }
}

class _AdvancesSection extends ConsumerWidget {
  final EmployeeEntity employee;
  const _AdvancesSection({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advancesAsync = ref.watch(employeeAdvancesProvider(employee.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
                child: Text('Avances sur salaire', style: AppTextStyles.h3)),
            AppButton(
              label: 'Nouvelle avance',
              icon: Icons.account_balance_wallet_outlined,
              onPressed: () => _ouvrirFormulaireAvance(context, ref, employee),
            ),
          ],
        ),
        const SizedBox(height: 12),
        advancesAsync.when(
          data: (advances) {
            if (advances.isEmpty) {
              return const EmptyState(
                icon: Icons.wallet_outlined,
                message: 'Aucune avance enregistrée.',
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: advances.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final a = advances[index];
                final Color couleur = switch (a.statut) {
                  'consommee' => AppColors.success,
                  'annulee' => AppColors.textSecondary,
                  _ => AppColors.warning,
                };
                final String label = switch (a.statut) {
                  'consommee' => 'Déduite',
                  'annulee' => 'Annulée',
                  _ => 'Active',
                };
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
                            Text(CurrencyFormatter.format(a.montant),
                                style: AppTextStyles.bodyBold),
                            Text(
                              '${DateFormatter.formatDate(a.date)}'
                              '${a.motif != null && a.motif!.isNotEmpty ? ' · ${a.motif}' : ''}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: couleur.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                color: couleur,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (a.statut == 'active')
                        IconButton(
                          tooltip: 'Annuler l\'avance',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () async {
                            await ref
                                .read(payrollRepositoryProvider)
                                .annulerAvance(a.id);
                            ref.invalidate(
                                employeeAdvancesProvider(employee.id));
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
        ),
      ],
    );
  }

  Future<void> _ouvrirFormulaireAvance(
      BuildContext context, WidgetRef ref, EmployeeEntity employee) async {
    final montantController = TextEditingController();
    final motifController = TextEditingController();
    DateTime date = DateTime.now();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nouvelle avance sur salaire'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Montant (FCFA)',
                  controller: montantController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormatter.formatDate(date)),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Motif', controller: motifController),
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
      ),
    );

    if (confirme != true) return;
    final montant = double.tryParse(montantController.text.trim()) ?? 0;
    if (montant <= 0) return;

    final user = ref.read(sessionProvider);
    if (user == null) return;

    await ref.read(payrollRepositoryProvider).createAdvance(
          employeeId: employee.id,
          montant: montant,
          date: date,
          motif: motifController.text.trim().isEmpty
              ? null
              : motifController.text.trim(),
          userId: user.id,
        );

    ref.invalidate(employeeAdvancesProvider(employee.id));
  }
}

class _CommissionConfigSection extends ConsumerWidget {
  final EmployeeEntity employee;
  const _CommissionConfigSection({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync =
        ref.watch(employeeCommissionConfigProvider(employee.id));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Configuration commerciale',
                      style: AppTextStyles.h3)),
              AppButton(
                label: 'Configurer',
                isOutlined: true,
                onPressed: () =>
                    _ouvrirFormulaireConfig(context, ref, employee, configAsync.value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          configAsync.when(
            data: (config) {
              if (config == null) {
                return const Text(
                  'Cet employé n\'est pas configuré comme commercial. '
                  'Configurez une commission pour qu\'il apparaisse dans '
                  'la liste des vendeurs lors d\'une vente et dans le '
                  'module Règlement des commissions.',
                  style: AppTextStyles.caption,
                );
              }
              final texte = config.estFixe
                  ? 'Commission fixe : '
                      '${CurrencyFormatter.format(config.montantFixeParPneu ?? 0)} '
                      'par article vendu'
                  : 'Commission au pourcentage : '
                      '${config.pourcentage?.toStringAsFixed(1) ?? 0} % '
                      'du prix de vente HT';
              return Text(texte, style: AppTextStyles.body);
            },
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Erreur: $e'),
          ),
        ],
      ),
    );
  }

  Future<void> _ouvrirFormulaireConfig(BuildContext context, WidgetRef ref,
      EmployeeEntity employee, CommissionConfigEntity? existant) async {
    String type = existant?.typeCommission ?? 'fixe';
    final montantFixeController = TextEditingController(
        text: existant?.montantFixeParPneu?.toStringAsFixed(0) ?? '');
    final pourcentageController = TextEditingController(
        text: existant?.pourcentage?.toStringAsFixed(1) ?? '');

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Commission de ${employee.nomComplet}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fixe', label: Text('Montant fixe')),
                    ButtonSegment(
                        value: 'pourcentage', label: Text('Pourcentage')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) =>
                      setDialogState(() => type = v.first),
                ),
                const SizedBox(height: 16),
                if (type == 'fixe')
                  AppTextField(
                    label: 'Montant fixe par article (FCFA)',
                    controller: montantFixeController,
                    keyboardType: TextInputType.number,
                  )
                else
                  AppTextField(
                    label: 'Pourcentage du prix de vente HT (%)',
                    controller: pourcentageController,
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
      ),
    );

    if (confirme != true) return;

    await ref.read(commissionsRepositoryProvider).upsertConfig(
          employeeId: employee.id,
          typeCommission: type,
          montantFixeParPneu:
              double.tryParse(montantFixeController.text.trim()),
          pourcentage: double.tryParse(pourcentageController.text.trim()),
        );

    ref.invalidate(employeeCommissionConfigProvider(employee.id));
    ref.invalidate(commercialEmployeesProvider);
  }
}
