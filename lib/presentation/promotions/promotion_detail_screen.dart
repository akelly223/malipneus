import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../domain/entities/promotion.dart';
import 'promotions_list_screen.dart';
import 'providers/promotions_provider.dart';

class PromotionDetailScreen extends ConsumerWidget {
  final int promotionId;
  const PromotionDetailScreen({super.key, required this.promotionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionAsync = ref.watch(promotionByIdProvider(promotionId));

    return Scaffold(
      appBar: AppBar(
        title: promotionAsync.when(
          data: (p) => Text(p?.nom ?? 'Promotion'),
          loading: () => const Text('Promotion'),
          error: (_, __) => const Text('Promotion'),
        ),
      ),
      body: promotionAsync.when(
        data: (promotion) {
          if (promotion == null) {
            return const Center(child: Text('Promotion introuvable.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EnteteCard(promotion: promotion),
                const SizedBox(height: 24),
                const Text('Performance', style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  'Mesurée uniquement sur les ventes facturées réellement '
                  'liées à cette promotion — jamais une estimation.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 12),
                _PerformanceSection(promotionId: promotion.id),
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

class _EnteteCard extends ConsumerWidget {
  final PromotionEntity promotion;
  const _EnteteCard({required this.promotion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remise = promotion.type == PromotionType.pourcentage
        ? '-${promotion.valeur.toStringAsFixed(0)}%'
        : '-${CurrencyFormatter.format(promotion.valeur)}';

    final (statutLabel, statutColor) = switch (promotion.statut) {
      PromotionStatut.active => ('Active', AppColors.success),
      PromotionStatut.planifiee => ('Planifiée', AppColors.primary),
      PromotionStatut.expiree => ('Expirée', AppColors.textSecondary),
      PromotionStatut.inactive => ('Inactive', AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                    Text(promotion.nom, style: AppTextStyles.h3),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statutColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statutLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statutColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$remise · ${DateFormatter.formatDate(promotion.dateDebut)} '
                  '→ ${DateFormatter.formatDate(promotion.dateFin)}',
                  style: AppTextStyles.caption,
                ),
                if (promotion.articlesLibelles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Pneus concernés', style: AppTextStyles.bodyBold),
                  const SizedBox(height: 4),
                  Text(
                    promotion.articlesLibelles.join(', '),
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
          AppButton(
            label: 'Modifier',
            isOutlined: true,
            onPressed: () async {
              await ouvrirFormulairePromotion(context, ref,
                  promotion: promotion);
              ref.invalidate(promotionByIdProvider(promotion.id));
              ref.invalidate(promotionPerformanceProvider(promotion.id));
            },
          ),
        ],
      ),
    );
  }
}

class _PerformanceSection extends ConsumerWidget {
  final int promotionId;
  const _PerformanceSection({required this.promotionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfAsync = ref.watch(promotionPerformanceProvider(promotionId));

    return perfAsync.when(
      data: (p) {
        if (p.nombreVentes == 0) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Aucune vente facturée liée à cette promotion pour le '
              'moment.',
              style: AppTextStyles.caption,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bloc('Ventes', [
              _ligne('Nombre de ventes', p.nombreVentes.toString()),
              _ligne('Pneus vendus', p.quantiteVendue.toStringAsFixed(0)),
              _ligneMontant('Chiffre d\'affaires réalisé', p.chiffreAffaires),
            ]),
            const SizedBox(height: 16),
            _bloc('Impact sur la marge', [
              _ligneMontant(
                'Remise accordée (manque à gagner)',
                p.remiseAccordee,
                couleur: AppColors.danger,
              ),
              _ligneMontant(
                  'Marge qui aurait été réalisée sans promo',
                  p.margeNormaleEstimee),
              _ligneMontant('Marge réellement réalisée', p.margeReelle,
                  gras: true,
                  couleur: p.margeReelle >= 0
                      ? AppColors.success
                      : AppColors.danger),
              _ligne('Part de marge perdue',
                  '${p.pourcentageMargePerdue.toStringAsFixed(1)} %'),
            ]),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur: $e'),
    );
  }

  Widget _bloc(String titre, List<Widget> lignes) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: AppTextStyles.bodyBold),
            const SizedBox(height: 8),
            ...lignes,
          ],
        ),
      );

  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.caption)),
            Text(valeur, style: AppTextStyles.body),
          ],
        ),
      );

  Widget _ligneMontant(String label, double montant,
          {bool gras = false, Color? couleur}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.caption)),
            Text(
              CurrencyFormatter.format(montant),
              style: (gras ? AppTextStyles.bodyBold : AppTextStyles.body)
                  .copyWith(color: couleur),
            ),
          ],
        ),
      );
}
