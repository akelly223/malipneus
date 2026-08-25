import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/loading.dart';
import '../expenses/expenses_list_screen.dart';
import '../expenses/providers/expenses_provider.dart';
import 'providers/loadings_provider.dart';

class LoadingDetailScreen extends ConsumerWidget {
  final int loadingId;
  const LoadingDetailScreen({super.key, required this.loadingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingAsync = ref.watch(loadingByIdProvider(loadingId));

    return Scaffold(
      appBar: AppBar(
        title: loadingAsync.when(
          data: (l) => Text(l?.nomAffiche ?? 'Chargement'),
          loading: () => const Text('Chargement'),
          error: (_, __) => const Text('Chargement'),
        ),
      ),
      body: loadingAsync.when(
        data: (loading) {
          if (loading == null) {
            return const Center(child: Text('Chargement introuvable.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EnteteCard(loading: loading),
                const SizedBox(height: 24),
                _RentabiliteSection(loadingId: loadingId),
                const SizedBox(height: 24),
                _AchatsSection(loadingId: loadingId),
                const SizedBox(height: 24),
                _DepensesSection(loadingId: loadingId),
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
  final LoadingEntity loading;
  const _EnteteCard({required this.loading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(loading.nomAffiche, style: AppTextStyles.h3),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Renommer',
                      onPressed: () => _renommer(context, ref, loading),
                    ),
                  ],
                ),
                Text(
                  '${loading.numero} · '
                  '${loading.supplierNom ?? 'Fournisseur non précisé'} · '
                  'Achat ${DateFormatter.formatDate(loading.dateChargement)}'
                  '${loading.dateArrivee != null ? ' · Arrivée ${DateFormatter.formatDate(loading.dateArrivee!)}' : ''}',
                  style: AppTextStyles.caption,
                ),
                if (loading.container != null &&
                    loading.container!.isNotEmpty)
                  Text('Container : ${loading.container}',
                      style: AppTextStyles.caption),
                if (loading.reference != null &&
                    loading.reference!.isNotEmpty)
                  Text('Référence : ${loading.reference}',
                      style: AppTextStyles.caption),
                if (loading.notes != null && loading.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(loading.notes!, style: AppTextStyles.body),
                  ),
              ],
            ),
          ),
          if (loading.statut == 'ouvert')
            AppButton(
              label: 'Clôturer',
              isOutlined: true,
              onPressed: () async {
                await ref
                    .read(loadingsRepositoryProvider)
                    .cloturerLoading(loading.id);
                ref.invalidate(loadingByIdProvider(loading.id));
                ref.invalidate(loadingsListProvider);
              },
            )
          else
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Clôturé',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Réouvrir',
                  isOutlined: true,
                  onPressed: () async {
                    await ref
                        .read(loadingsRepositoryProvider)
                        .rouvrirLoading(loading.id);
                    ref.invalidate(loadingByIdProvider(loading.id));
                    ref.invalidate(loadingsListProvider);
                    ref.invalidate(loadingRentabiliteProvider(loading.id));
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _renommer(
      BuildContext context, WidgetRef ref, LoadingEntity loading) async {
    final controller = TextEditingController(text: loading.nom ?? '');
    final nouveauNom = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renommer le chargement'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom du chargement',
            hintText: 'Ex : Chargement Awa, Chargement Bamako...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: 'Enregistrer',
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (nouveauNom == null) return;
    await ref.read(loadingsRepositoryProvider).updateLoading(
          id: loading.id,
          nom: nouveauNom.isEmpty ? null : nouveauNom,
          supplierId: loading.supplierId,
          dateChargement: loading.dateChargement,
          dateArrivee: loading.dateArrivee,
          container: loading.container,
          reference: loading.reference,
          notes: loading.notes,
        );
    ref.invalidate(loadingByIdProvider(loading.id));
    ref.invalidate(loadingsListProvider);
  }
}

class _RentabiliteSection extends ConsumerWidget {
  final int loadingId;
  const _RentabiliteSection({required this.loadingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentaAsync = ref.watch(loadingRentabiliteProvider(loadingId));

    return rentaAsync.when(
      data: (r) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rentabilité', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          if (r.erreursAllocation.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.danger, size: 18),
                      SizedBox(width: 8),
                      Text('Répartition incomplète',
                          style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...r.erreursAllocation.map((e) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(e,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.danger)),
                      )),
                  if (r.depensesNonAllouees > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Total non réparti : '
                        '${CurrencyFormatter.format(r.depensesNonAllouees)} '
                        '(inclus dans le coût total ci-dessous, mais pas '
                        'encore dans le détail par article)',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          if (r.lignes.isNotEmpty) ...[
            const Text('Détail par article', style: AppTextStyles.bodyBold),
            const SizedBox(height: 4),
            Text(
              'Le coût réel de chaque article — jamais une moyenne du '
              'chargement.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 10),
            _TableauDetailArticles(lignes: r.lignes),
            const SizedBox(height: 20),
            const Text('Synthèse globale (indicateur secondaire)',
                style: AppTextStyles.bodyBold),
            const SizedBox(height: 10),
          ],
          _bloc('Stock', [
            _ligne('Quantité reçue', r.quantiteRecue.toStringAsFixed(0)),
            _ligne('Quantité vendue', r.quantiteVendue.toStringAsFixed(0)),
            _ligne('Quantité restante', r.quantiteRestante.toStringAsFixed(0)),
            _ligne('Pertes', r.pertes.toStringAsFixed(0)),
            _ligne('Ajustements', r.ajustements.toStringAsFixed(0)),
          ]),
          const SizedBox(height: 16),
          _bloc('Coûts', [
            _ligneMontant('Prix d\'achat', r.prixAchatTotal),
            _ligneMontant('Dépenses imputées', r.depensesTotal),
            _ligneMontant('Coût total', r.coutTotal, gras: true),
            _ligneMontant('Prix de revient unitaire', r.prixRevientUnitaire),
          ]),
          const SizedBox(height: 16),
          _bloc('Ventes', [
            _ligneMontant('Chiffre d\'affaires', r.chiffreAffaires),
            _ligneMontant('Prix de vente moyen', r.prixVenteMoyen),
          ]),
          const SizedBox(height: 16),
          _bloc('Rentabilité', [
            _ligneMontant('Coût des produits vendus', r.coutDesProduitsVendus),
            _ligneMontant('Marge brute', r.margeBrute),
            _ligneMontant('Commissions commerciales', r.commissionsCommerciales),
            _ligneMontant('Bénéfice estimé', r.beneficeEstime,
                gras: true,
                couleur: r.beneficeEstime >= 0
                    ? AppColors.success
                    : AppColors.danger),
          ]),
        ],
      ),
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

/// Tableau "Qté / Achat/U / Part dépenses/U / Revient/U / Vente/U /
/// Marge/U / Marge totale" — le coût réel de chaque ligne d'achat,
/// jamais une moyenne du chargement.
class _TableauDetailArticles extends StatelessWidget {
  final List<ArticleRentabiliteLigne> lignes;
  const _TableauDetailArticles({required this.lignes});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.background),
          columns: const [
            DataColumn(label: Text('Article')),
            DataColumn(label: Text('Qté'), numeric: true),
            DataColumn(label: Text('Achat/U'), numeric: true),
            DataColumn(label: Text('Part dépenses/U'), numeric: true),
            DataColumn(label: Text('Revient/U'), numeric: true),
            DataColumn(label: Text('Vente/U'), numeric: true),
            DataColumn(label: Text('Marge/U'), numeric: true),
            DataColumn(label: Text('Marge totale'), numeric: true),
          ],
          rows: lignes
              .map((l) => DataRow(cells: [
                    DataCell(Text(l.articleNom)),
                    DataCell(Text(l.quantite.toStringAsFixed(0))),
                    DataCell(Text(CurrencyFormatter.format(l.prixAchatUnitaire))),
                    DataCell(
                        Text(CurrencyFormatter.format(l.partDepensesUnitaire))),
                    DataCell(Text(
                      CurrencyFormatter.format(l.coutRevientUnitaire),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )),
                    DataCell(Text(CurrencyFormatter.format(l.prixVenteUnitaire))),
                    DataCell(Text(
                      CurrencyFormatter.format(l.margeUnitaire),
                      style: TextStyle(
                        color: l.margeUnitaire >= 0
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                    DataCell(Text(
                      CurrencyFormatter.format(l.margeTotale),
                      style: TextStyle(
                        color: l.margeTotale >= 0
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    )),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}

class _AchatsSection extends ConsumerWidget {
  final int loadingId;
  const _AchatsSection({required this.loadingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achatsAsync = ref.watch(purchasesForLoadingProvider(loadingId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
                child: Text('Achats liés', style: AppTextStyles.h3)),
            AppButton(
              label: 'Ajouter un achat',
              icon: Icons.add_rounded,
              onPressed: () async {
                await context.push('/purchases/new?chargementId=$loadingId');
                ref.invalidate(purchasesForLoadingProvider(loadingId));
                ref.invalidate(loadingRentabiliteProvider(loadingId));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        achatsAsync.when(
          data: (achats) {
            if (achats.isEmpty) {
              return const EmptyState(
                icon: Icons.shopping_cart_outlined,
                message: 'Aucun achat rattaché à ce chargement pour '
                    'l\'instant. Cliquez sur "Ajouter un achat" pour '
                    'enregistrer les articles reçus sur ce chargement.',
              );
            }
            return Column(
              children: achats
                  .map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(a.numero,
                                    style: AppTextStyles.bodyBold)),
                            Text(CurrencyFormatter.format(a.totalFinal)),
                          ],
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
        ),
      ],
    );
  }
}

class _DepensesSection extends ConsumerWidget {
  final int loadingId;
  const _DepensesSection({required this.loadingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depensesAsync = ref.watch(expensesForLoadingProvider(loadingId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
                child: Text('Dépenses liées', style: AppTextStyles.h3)),
            AppButton(
              label: 'Ajouter une dépense',
              icon: Icons.add_rounded,
              onPressed: () async {
                await ouvrirFormulaireDepense(context, ref,
                    chargementId: loadingId);
                ref.invalidate(loadingRentabiliteProvider(loadingId));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        depensesAsync.when(
          data: (depenses) {
            if (depenses.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_outlined,
                message: 'Aucune dépense imputée à ce chargement '
                    '(transport, douane, transitaire, manutention...).',
              );
            }
            return Column(
              children: depenses
                  .map((d) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
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
                                  Text(d.categorieNom ?? '—',
                                      style: AppTextStyles.bodyBold),
                                  if (d.description != null)
                                    Text(d.description!,
                                        style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.format(d.montant)),
                          ],
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
        ),
      ],
    );
  }
}
