import 'package:file_picker/file_picker.dart';
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
import '../../core/services/expense_attachment_service.dart';
import '../../core/widgets/article_autocomplete_field.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/purchase.dart';
import '../loadings/providers/loadings_provider.dart';
import 'providers/expenses_provider.dart';

class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  ConsumerState<ExpensesListScreen> createState() =>
      _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen> {
  String _recherche = '';
  int? _filtreCategorieId;

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesListProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépenses'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouvelle dépense',
              icon: Icons.add_rounded,
              onPressed: () => ouvrirFormulaireDepense(context, ref),
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
                      hintText: 'Rechercher (description, fournisseur)...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) => setState(() => _recherche = v.trim()),
                  ),
                ),
                const SizedBox(width: 16),
                categoriesAsync.when(
                  data: (cats) => DropdownButton<int?>(
                    value: _filtreCategorieId,
                    hint: const Text('Toutes catégories'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Toutes catégories')),
                      ...cats.map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.nom))),
                    ],
                    onChanged: (v) => setState(() => _filtreCategorieId = v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: expensesAsync.when(
                data: (expenses) {
                  var filtres = expenses;
                  if (_filtreCategorieId != null) {
                    filtres = filtres
                        .where((e) => e.categorieId == _filtreCategorieId)
                        .toList();
                  }
                  if (_recherche.isNotEmpty) {
                    final q = _recherche.toLowerCase();
                    filtres = filtres
                        .where((e) =>
                            (e.description ?? '').toLowerCase().contains(q) ||
                            (e.fournisseurOuPersonne ?? '')
                                .toLowerCase()
                                .contains(q))
                        .toList();
                  }
                  if (filtres.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_outlined,
                      message: 'Aucune dépense trouvée.',
                    );
                  }
                  final total =
                      filtres.fold<double>(0, (s, e) => s + e.montant);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${filtres.length} dépense(s) — total '
                          '${CurrencyFormatter.format(total)}',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtres.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _ExpenseTile(expense: filtres[index]),
                        ),
                      ),
                    ],
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

class _ExpenseTile extends StatelessWidget {
  final ExpenseEntity expense;
  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                Text(expense.categorieNom ?? '—',
                    style: AppTextStyles.bodyBold),
                Text(
                  [
                    DateFormatter.formatDate(expense.date),
                    if (expense.description != null &&
                        expense.description!.isNotEmpty)
                      expense.description,
                    if (expense.fournisseurOuPersonne != null &&
                        expense.fournisseurOuPersonne!.isNotEmpty)
                      expense.fournisseurOuPersonne,
                    if (expense.chargementNumero != null)
                      'Chargement ${expense.chargementNumero}',
                  ].join(' · '),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (expense.pieceJustificativePath != null)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.attach_file_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
          Text(CurrencyFormatter.format(expense.montant),
              style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}

Future<void> ouvrirFormulaireDepense(BuildContext context, WidgetRef ref,
    {int? chargementId}) async {
  final categories = await ref.read(expensesRepositoryProvider).getAllCategories();
  int? categorieId = categories.isNotEmpty ? categories.first.id : null;
  final montantController = TextEditingController();
  final descriptionController = TextEditingController();
  final fournisseurController = TextEditingController();
  DateTime date = DateTime.now();
  String? pieceJustificativePath;
  int? articleId;
  String? articleNom;
  String methodeAllocation = 'quantite';
  // purchaseItemId -> montant saisi (méthode 'manuelle' uniquement).
  final Map<int, TextEditingController> allocationsManuelles = {};

  List<PurchaseItemEntity> lignesAchatChargement = [];
  if (chargementId != null) {
    final achats =
        await ref.read(purchasesForLoadingProvider(chargementId).future);
    lignesAchatChargement = achats.expand((a) => a.items).toList();
    for (final l in lignesAchatChargement) {
      allocationsManuelles[l.id] = TextEditingController();
    }
  }

  if (!context.mounted) return;

  final confirme = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Nouvelle dépense'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: categorieId,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: categories
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.nom)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => categorieId = v),
                ),
                const SizedBox(height: 12),
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
                AppTextField(
                    label: 'Description',
                    controller: descriptionController,
                    maxLines: 2),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'Fournisseur / personne concernée (optionnel)',
                    controller: fournisseurController),
                const SizedBox(height: 12),
                if (articleId != null)
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Article concerné',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setDialogState(() {
                          articleId = null;
                          articleNom = null;
                        }),
                      ),
                    ),
                    child: Text(articleNom ?? ''),
                  )
                else
                  ArticleAutocompleteField(
                    label: 'Article concerné (optionnel)',
                    onSearch: (query) => ref
                        .read(articleRepositoryProvider)
                        .searchArticles(query),
                    onSelected: (article) => setDialogState(() {
                      articleId = article.id;
                      articleNom = article.nom;
                    }),
                  ),
                if (chargementId != null && articleId == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Dépense partagée entre tous les articles de ce '
                    'chargement — comment la répartir ?',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: methodeAllocation,
                    decoration: const InputDecoration(
                        labelText: 'Méthode de répartition'),
                    items: const [
                      DropdownMenuItem(
                          value: 'quantite',
                          child: Text('Par quantité')),
                      DropdownMenuItem(
                          value: 'valeur_achat',
                          child: Text('Par valeur d\'achat')),
                      DropdownMenuItem(
                          value: 'poids', child: Text('Par poids')),
                      DropdownMenuItem(
                          value: 'manuelle',
                          child: Text('Manuellement')),
                    ],
                    onChanged: (v) => setDialogState(
                        () => methodeAllocation = v ?? 'quantite'),
                  ),
                  if (methodeAllocation == 'manuelle') ...[
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final montant =
                          double.tryParse(montantController.text.trim()) ?? 0;
                      final saisi = allocationsManuelles.values.fold<double>(
                          0,
                          (s, c) => s + (double.tryParse(c.text.trim()) ?? 0));
                      final restant = montant - saisi;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final ligne in lignesAchatChargement)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${ligne.articleNom} '
                                      '(${ligne.quantite.toStringAsFixed(0)})',
                                      style: AppTextStyles.caption,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          allocationsManuelles[ligne.id],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'Montant'),
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            restant.abs() < 0.01
                                ? 'Répartition complète.'
                                : 'Reste à attribuer : '
                                    '${restant.toStringAsFixed(0)} FCFA',
                            style: AppTextStyles.caption.copyWith(
                              color: restant.abs() < 0.01
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pieceJustificativePath != null
                            ? 'Justificatif joint'
                            : 'Aucun justificatif',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      label: const Text('Joindre'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            'pdf',
                            'jpg',
                            'jpeg',
                            'png'
                          ],
                          dialogTitle: 'Sélectionner un justificatif',
                        );
                        final path = result?.files.single.path;
                        if (path != null) {
                          final copie = await ExpenseAttachmentService
                              .importerJustificatif(path);
                          setDialogState(
                              () => pieceJustificativePath = copie);
                        }
                      },
                    ),
                  ],
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
  final montant = double.tryParse(montantController.text.trim()) ?? 0;
  if (montant <= 0 || categorieId == null) return;

  final user = ref.read(sessionProvider);
  final expensesRepo = ref.read(expensesRepositoryProvider);

  final expenseId = await expensesRepo.createExpense(
    categorieId: categorieId!,
    montant: montant,
    date: date,
    description: descriptionController.text.trim().isEmpty
        ? null
        : descriptionController.text.trim(),
    fournisseurOuPersonne: fournisseurController.text.trim().isEmpty
        ? null
        : fournisseurController.text.trim(),
    chargementId: chargementId,
    articleId: articleId,
    methodeAllocation:
        (chargementId != null && articleId == null) ? methodeAllocation : 'quantite',
    pieceJustificativePath: pieceJustificativePath,
    createdById: user?.id,
    createdByNom: user?.nom,
  );

  if (chargementId != null &&
      articleId == null &&
      methodeAllocation == 'manuelle') {
    final montants = <int, double>{
      for (final entry in allocationsManuelles.entries)
        entry.key: double.tryParse(entry.value.text.trim()) ?? 0,
    };
    await expensesRepo.setAllocationsManuelles(expenseId, montants);
  }

  ref.invalidate(expensesListProvider);
  if (chargementId != null) {
    ref.invalidate(expensesForLoadingProvider(chargementId));
    ref.invalidate(loadingRentabiliteProvider(chargementId));
  }
}
