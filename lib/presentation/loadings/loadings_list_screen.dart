import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/date_formatter.dart';
import 'providers/loadings_provider.dart';

class LoadingsListScreen extends ConsumerWidget {
  const LoadingsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingsAsync = ref.watch(loadingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chargements'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouveau chargement',
              icon: Icons.add_rounded,
              onPressed: () => _ouvrirFormulaire(context, ref),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: loadingsAsync.when(
          data: (loadings) {
            if (loadings.isEmpty) {
              return const EmptyState(
                icon: Icons.local_shipping_outlined,
                message: 'Aucun chargement enregistré.',
              );
            }
            return ListView.separated(
              itemCount: loadings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final l = loadings[index];
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/loadings/${l.id}'),
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
                                Text(l.nomAffiche, style: AppTextStyles.bodyBold),
                                Text(
                                  '${l.numero} · '
                                  '${l.supplierNom ?? 'Fournisseur non précisé'} · '
                                  '${DateFormatter.formatDate(l.dateChargement)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (l.statut == 'ouvert'
                                      ? AppColors.warning
                                      : AppColors.success)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l.statut == 'ouvert' ? 'Ouvert' : 'Clôturé',
                              style: TextStyle(
                                color: l.statut == 'ouvert'
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

  Future<void> _ouvrirFormulaire(BuildContext context, WidgetRef ref) async {
    DateTime date = DateTime.now();
    DateTime? dateArrivee;
    final nomController = TextEditingController();
    final notesController = TextEditingController();
    final containerController = TextEditingController();
    final referenceController = TextEditingController();
    int? supplierId;

    final suppliers = await ref.read(supplierRepositoryProvider).getAllSuppliers();

    if (!context.mounted) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nouveau chargement'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du chargement',
                    hintText: 'Ex : Chargement Awa, Chargement Bamako...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: supplierId,
                  decoration:
                      const InputDecoration(labelText: 'Fournisseur (optionnel)'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Aucun')),
                    ...suppliers.map(
                        (s) => DropdownMenuItem(value: s.id, child: Text(s.nom))),
                  ],
                  onChanged: (v) => setDialogState(() => supplierId = v),
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
                    decoration:
                        const InputDecoration(labelText: 'Date d\'achat'),
                    child: Text(DateFormatter.formatDate(date)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: dateArrivee ?? date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (picked != null) {
                      setDialogState(() => dateArrivee = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date d\'arrivée (optionnelle)',
                      suffixIcon: dateArrivee != null
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () =>
                                  setDialogState(() => dateArrivee = null),
                            )
                          : null,
                    ),
                    child: Text(dateArrivee != null
                        ? DateFormatter.formatDate(dateArrivee!)
                        : 'Non arrivé'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: containerController,
                  decoration: const InputDecoration(
                      labelText: 'Numéro de container (optionnel)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                      labelText: 'Référence (optionnelle)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
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

    if (confirme != true) return;
    final user = ref.read(sessionProvider);
    final id = await ref.read(loadingsRepositoryProvider).createLoading(
          nom: nomController.text.trim().isEmpty
              ? null
              : nomController.text.trim(),
          supplierId: supplierId,
          dateChargement: date,
          dateArrivee: dateArrivee,
          container: containerController.text.trim().isEmpty
              ? null
              : containerController.text.trim(),
          reference: referenceController.text.trim().isEmpty
              ? null
              : referenceController.text.trim(),
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
          createdById: user?.id,
          createdByNom: user?.nom,
        );
    ref.invalidate(loadingsListProvider);
    if (context.mounted) context.push('/loadings/$id');
  }
}
