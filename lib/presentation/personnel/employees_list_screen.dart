import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'providers/personnel_provider.dart';

class EmployeesListScreen extends ConsumerStatefulWidget {
  const EmployeesListScreen({super.key});

  @override
  ConsumerState<EmployeesListScreen> createState() =>
      _EmployeesListScreenState();
}

class _EmployeesListScreenState extends ConsumerState<EmployeesListScreen> {
  String _recherche = '';
  bool _seulementActifs = true;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personnel'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouvel employé',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () => _ouvrirFormulaire(context, ref, null),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un employé...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) => setState(() => _recherche = v.trim()),
                  ),
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('Actifs seulement'),
                  selected: _seulementActifs,
                  onSelected: (v) => setState(() => _seulementActifs = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: employeesAsync.when(
                data: (employees) {
                  var filtres = employees;
                  if (_seulementActifs) {
                    filtres = filtres.where((e) => e.estActif).toList();
                  }
                  if (_recherche.isNotEmpty) {
                    final q = _recherche.toLowerCase();
                    filtres = filtres
                        .where((e) =>
                            e.nom.toLowerCase().contains(q) ||
                            e.prenom.toLowerCase().contains(q) ||
                            (e.posteNom ?? '').toLowerCase().contains(q))
                        .toList();
                  }
                  if (filtres.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outline_rounded,
                      message: 'Aucun employé trouvé.',
                    );
                  }
                  return ListView.separated(
                    itemCount: filtres.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final e = filtres[index];
                      return _EmployeeTile(employee: e);
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final EmployeeEntity employee;
  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/employees/${employee.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Text(
                  employee.prenom.isNotEmpty
                      ? employee.prenom[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.nomComplet, style: AppTextStyles.bodyBold),
                    Text(
                      '${employee.posteNom ?? '—'} · '
                      '${CurrencyFormatter.format(employee.salaireBase)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (!employee.estActif)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Inactif',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                )
              else
                Text(
                  'Embauché le ${DateFormatter.formatDate(employee.dateEmbauche)}',
                  style: AppTextStyles.caption,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _ouvrirFormulaire(
    BuildContext context, WidgetRef ref, EmployeeEntity? existant) async {
  final nomController = TextEditingController(text: existant?.nom);
  final prenomController = TextEditingController(text: existant?.prenom);
  final telController = TextEditingController(text: existant?.telephone);
  final contratController =
      TextEditingController(text: existant?.typeContrat);
  final salaireController = TextEditingController(
      text: existant != null ? existant.salaireBase.toStringAsFixed(0) : '');
  final notesController = TextEditingController(text: existant?.notes);
  DateTime dateEmbauche = existant?.dateEmbauche ?? DateTime.now();
  int? posteId = existant?.posteId;

  final postes = await ref.read(jobPositionsProvider.future);

  if (!context.mounted) return;

  final confirme = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title:
            Text(existant == null ? 'Nouvel employé' : 'Modifier l\'employé'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: AppTextField(
                            label: 'Nom', controller: nomController)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: AppTextField(
                            label: 'Prénom', controller: prenomController)),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Téléphone', controller: telController),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: posteId,
                  decoration: const InputDecoration(labelText: 'Poste'),
                  items: postes
                      .map((p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.nom)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => posteId = v),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: dateEmbauche,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (picked != null) {
                      setDialogState(() => dateEmbauche = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Date d\'embauche'),
                    child: Text(DateFormatter.formatDate(dateEmbauche)),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Type de contrat',
                  controller: contratController,
                  hint: 'Ex: CDI, CDD, Journalier...',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Salaire de base (FCFA)',
                  controller: salaireController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Notes',
                  controller: notesController,
                  maxLines: 3,
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
  if (nomController.text.trim().isEmpty ||
      prenomController.text.trim().isEmpty ||
      posteId == null) {
    return;
  }

  final repo = ref.read(personnelRepositoryProvider);
  final salaire = double.tryParse(
          salaireController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '')) ??
      0;
  final user = ref.read(sessionProvider);

  if (existant == null) {
    await repo.createEmployee(
      nom: nomController.text.trim(),
      prenom: prenomController.text.trim(),
      telephone:
          telController.text.trim().isEmpty ? null : telController.text.trim(),
      posteId: posteId!,
      dateEmbauche: dateEmbauche,
      typeContrat: contratController.text.trim().isEmpty
          ? null
          : contratController.text.trim(),
      salaireBase: salaire,
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
      createdById: user?.id,
    );
  } else {
    await repo.updateEmployee(EmployeeEntity(
      id: existant.id,
      nom: nomController.text.trim(),
      prenom: prenomController.text.trim(),
      telephone: telController.text.trim(),
      posteId: posteId!,
      dateEmbauche: dateEmbauche,
      typeContrat: contratController.text.trim(),
      salaireBase: salaire,
      statut: existant.statut,
      dateDepart: existant.dateDepart,
      notes: notesController.text.trim(),
      userId: existant.userId,
      dateCreation: existant.dateCreation,
    ));
  }

  ref.invalidate(employeesListProvider);
  ref.invalidate(activeEmployeesProvider);
  if (existant != null) ref.invalidate(employeeByIdProvider(existant.id));
}
