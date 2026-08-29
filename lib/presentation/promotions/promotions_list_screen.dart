import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/article_autocomplete_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/promotion.dart';
import 'providers/promotions_provider.dart';

class PromotionsListScreen extends ConsumerWidget {
  const PromotionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsAsync = ref.watch(promotionsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouvelle promotion',
              icon: Icons.add_rounded,
              onPressed: () => ouvrirFormulairePromotion(context, ref),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: promotionsAsync.when(
          data: (promotions) {
            if (promotions.isEmpty) {
              return const EmptyState(
                icon: Icons.local_offer_outlined,
                message: 'Aucune promotion. Créez-en une pour appliquer '
                    'automatiquement une remise sur des pneus pendant une '
                    'période donnée.',
              );
            }
            return ListView.separated(
              itemCount: promotions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _PromotionTile(
                promotion: promotions[index],
                onEdit: () => ouvrirFormulairePromotion(context, ref,
                    promotion: promotions[index]),
                onDelete: () =>
                    _confirmerSuppression(context, ref, promotions[index]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }

  Future<void> _confirmerSuppression(
      BuildContext context, WidgetRef ref, PromotionEntity promotion) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la promotion ?'),
        content: Text(
            'La promotion "${promotion.nom}" sera définitivement supprimée. '
            'Les ventes déjà enregistrées ne sont pas affectées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler')),
          AppButton(
            label: 'Supprimer',
            isDanger: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await ref.read(promotionsRepositoryProvider).deletePromotion(promotion.id);
    ref.invalidate(promotionsListProvider);
    ref.invalidate(activePromotionsMapProvider);
  }
}

class _PromotionTile extends StatelessWidget {
  final PromotionEntity promotion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PromotionTile({
    required this.promotion,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final remise = promotion.type == PromotionType.pourcentage
        ? '-${promotion.valeur.toStringAsFixed(0)}%'
        : '-${CurrencyFormatter.format(promotion.valeur)}';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/promotions/${promotion.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(promotion.nom, style: AppTextStyles.bodyBold),
                        const SizedBox(width: 10),
                        _StatutBadge(statut: promotion.statut),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormatter.formatDate(promotion.dateDebut)} → '
                      '${DateFormatter.formatDate(promotion.dateFin)} · '
                      '${promotion.articleIds.length} pneu'
                      '${promotion.articleIds.length != 1 ? 's' : ''}',
                      style: AppTextStyles.caption,
                    ),
                    if (promotion.articlesLibelles.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        promotion.articlesLibelles.join(', '),
                        style: AppTextStyles.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(remise,
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.primary)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Modifier',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.danger),
                onPressed: onDelete,
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final PromotionStatut statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (statut) {
      PromotionStatut.active => ('Active', AppColors.success),
      PromotionStatut.planifiee => ('Planifiée', AppColors.primary),
      PromotionStatut.expiree => ('Expirée', AppColors.textSecondary),
      PromotionStatut.inactive => ('Inactive', AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

Future<void> ouvrirFormulairePromotion(BuildContext context, WidgetRef ref,
    {PromotionEntity? promotion}) async {
  final nomController = TextEditingController(text: promotion?.nom ?? '');
  final valeurController = TextEditingController(
      text: promotion != null ? promotion.valeur.toStringAsFixed(0) : '');
  PromotionType type = promotion?.type ?? PromotionType.pourcentage;
  DateTime dateDebut = promotion?.dateDebut ?? DateTime.now();
  DateTime dateFin =
      promotion?.dateFin ?? DateTime.now().add(const Duration(days: 7));
  bool actif = promotion?.actif ?? true;

  // (id, code — nom) des pneus sélectionnés.
  final articlesSelectionnes = <int, String>{
    if (promotion != null)
      for (var i = 0; i < promotion.articleIds.length; i++)
        if (i < promotion.articlesLibelles.length)
          promotion.articleIds[i]: promotion.articlesLibelles[i],
  };

  if (!context.mounted) return;

  final confirme = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(
            promotion == null ? 'Nouvelle promotion' : 'Modifier la promotion'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                    label: 'Nom de la promotion', controller: nomController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PromotionType>(
                        initialValue: type,
                        decoration:
                            const InputDecoration(labelText: 'Type de remise'),
                        items: const [
                          DropdownMenuItem(
                              value: PromotionType.pourcentage,
                              child: Text('Pourcentage (%)')),
                          DropdownMenuItem(
                              value: PromotionType.montant,
                              child: Text('Montant fixe (FCFA)')),
                        ],
                        onChanged: (v) => setDialogState(
                            () => type = v ?? PromotionType.pourcentage),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: type == PromotionType.pourcentage
                            ? 'Valeur (%)'
                            : 'Valeur (FCFA)',
                        controller: valeurController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
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
                          decoration: const InputDecoration(labelText: 'Début'),
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
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Promotion active'),
                  subtitle: const Text(
                      "Désactive immédiatement la remise sans changer les dates"),
                  value: actif,
                  onChanged: (v) => setDialogState(() => actif = v),
                ),
                const SizedBox(height: 8),
                Text('Pneus concernés', style: AppTextStyles.bodyBold),
                const SizedBox(height: 6),
                if (articlesSelectionnes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: articlesSelectionnes.entries
                        .map((e) => Chip(
                              label: Text(e.value),
                              onDeleted: () => setDialogState(
                                  () => articlesSelectionnes.remove(e.key)),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 8),
                ArticleAutocompleteField(
                  label: 'Ajouter un pneu',
                  onSearch: (query) =>
                      ref.read(articleRepositoryProvider).searchArticles(query),
                  onSelected: (ArticleEntity article) => setDialogState(() {
                    articlesSelectionnes[article.id] =
                        '${article.code} — ${article.nom}';
                  }),
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

  final nom = nomController.text.trim();
  final valeur = double.tryParse(valeurController.text.trim()) ?? 0;
  if (nom.isEmpty || valeur <= 0 || articlesSelectionnes.isEmpty) return;

  // La fin de journée est incluse : une promotion se terminant le 31
  // couvre toute la journée du 31, pas seulement minuit.
  final dateFinInclusive =
      DateTime(dateFin.year, dateFin.month, dateFin.day, 23, 59, 59);

  final repo = ref.read(promotionsRepositoryProvider);
  if (promotion == null) {
    await repo.createPromotion(
      nom: nom,
      type: type,
      valeur: valeur,
      dateDebut: dateDebut,
      dateFin: dateFinInclusive,
      actif: actif,
      articleIds: articlesSelectionnes.keys.toList(),
    );
  } else {
    await repo.updatePromotion(
      id: promotion.id,
      nom: nom,
      type: type,
      valeur: valeur,
      dateDebut: dateDebut,
      dateFin: dateFinInclusive,
      actif: actif,
      articleIds: articlesSelectionnes.keys.toList(),
    );
  }

  ref.invalidate(promotionsListProvider);
  ref.invalidate(activePromotionsMapProvider);
}
