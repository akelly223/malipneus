import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/repository_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/loading_simulation_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/article_autocomplete_field.dart';
import '../../domain/entities/article.dart';

/// Simulateur de coût de revient / marge — permet d'estimer, AVANT
/// d'acheter quoi que ce soit, ce que coûtera réellement chaque pneu
/// une fois les dépenses partagées (transport, douane...) réparties.
/// Purement local : rien n'est lu ni écrit en base, aucun chargement ni
/// achat n'est créé — c'est un calculateur, pas un formulaire de saisie.
class LoadingSimulatorScreen extends ConsumerStatefulWidget {
  const LoadingSimulatorScreen({super.key});

  @override
  ConsumerState<LoadingSimulatorScreen> createState() =>
      _LoadingSimulatorScreenState();
}

class _LigneForm {
  final int id;
  final nomCtrl = TextEditingController();
  final quantiteCtrl = TextEditingController();
  final prixAchatCtrl = TextEditingController();
  final poidsCtrl = TextEditingController();
  final prixVenteCtrl = TextEditingController();

  _LigneForm(this.id);

  void dispose() {
    nomCtrl.dispose();
    quantiteCtrl.dispose();
    prixAchatCtrl.dispose();
    poidsCtrl.dispose();
    prixVenteCtrl.dispose();
  }
}

class _DepenseForm {
  final int id;
  final descriptionCtrl = TextEditingController();
  final montantCtrl = TextEditingController();
  String methode = 'quantite';
  int? ligneCibleId;

  _DepenseForm(this.id);

  void dispose() {
    descriptionCtrl.dispose();
    montantCtrl.dispose();
  }
}

class _LoadingSimulatorScreenState
    extends ConsumerState<LoadingSimulatorScreen> {
  int _nextId = 0;
  final List<_LigneForm> _lignes = [];
  final List<_DepenseForm> _depenses = [];

  @override
  void initState() {
    super.initState();
    _ajouterLigne();
  }

  @override
  void dispose() {
    for (final l in _lignes) {
      l.dispose();
    }
    for (final d in _depenses) {
      d.dispose();
    }
    super.dispose();
  }

  void _ajouterLigne() {
    setState(() => _lignes.add(_LigneForm(_nextId++)));
  }

  /// Ajoute une ligne préremplie à partir d'un pneu déjà au catalogue
  /// (ex : taper "55R16" propose "Pneu Tourisme 205/55R16") — prix
  /// d'achat, poids et prix de vente actuels du catalogue, librement
  /// ajustables ensuite pour la simulation.
  void _ajouterLigneDepuisArticle(ArticleEntity article) {
    final l = _LigneForm(_nextId++);
    l.nomCtrl.text = article.nom;
    l.quantiteCtrl.text = '1';
    l.prixAchatCtrl.text = article.prixAchat.toStringAsFixed(0);
    if (article.poids != null) {
      l.poidsCtrl.text = article.poids!.toStringAsFixed(2);
    }
    l.prixVenteCtrl.text = article.prixVente.toStringAsFixed(0);
    setState(() => _lignes.add(l));
  }

  void _supprimerLigne(_LigneForm l) {
    setState(() {
      _lignes.remove(l);
      for (final d in _depenses) {
        if (d.ligneCibleId == l.id) d.ligneCibleId = null;
      }
      l.dispose();
    });
  }

  void _ajouterDepense() {
    setState(() => _depenses.add(_DepenseForm(_nextId++)));
  }

  void _supprimerDepense(_DepenseForm d) {
    setState(() {
      _depenses.remove(d);
      d.dispose();
    });
  }

  double _parseDouble(String texte) =>
      double.tryParse(texte.trim().replaceAll(',', '.')) ?? 0;

  SimulationResultat _calculer() {
    final idParIndex = <int, int>{};
    final lignes = <SimulationLigne>[];
    for (var i = 0; i < _lignes.length; i++) {
      final l = _lignes[i];
      idParIndex[l.id] = i;
      final nom = l.nomCtrl.text.trim();
      lignes.add(SimulationLigne(
        articleNom: nom.isEmpty ? 'Article ${i + 1}' : nom,
        quantite: _parseDouble(l.quantiteCtrl.text),
        prixAchatUnitaire: _parseDouble(l.prixAchatCtrl.text),
        poidsUnitaire: l.poidsCtrl.text.trim().isEmpty
            ? null
            : _parseDouble(l.poidsCtrl.text),
        prixVenteUnitaire: l.prixVenteCtrl.text.trim().isEmpty
            ? null
            : _parseDouble(l.prixVenteCtrl.text),
      ));
    }

    final depenses = _depenses
        .where((d) => d.montantCtrl.text.trim().isNotEmpty)
        .map((d) => SimulationDepense(
              description: d.descriptionCtrl.text.trim().isEmpty
                  ? 'Dépense'
                  : d.descriptionCtrl.text.trim(),
              montant: _parseDouble(d.montantCtrl.text),
              methodeAllocation: d.methode,
              ligneCibleIndex: d.ligneCibleId != null
                  ? idParIndex[d.ligneCibleId!]
                  : null,
            ))
        .toList();

    return LoadingSimulationService.simuler(lignes: lignes, depenses: depenses);
  }

  @override
  Widget build(BuildContext context) {
    final resultat = _calculer();

    return Scaffold(
      appBar: AppBar(title: const Text('Simulateur de coût de revient')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _banniereInfo(),
            const SizedBox(height: 20),
            _sectionLignes(),
            const SizedBox(height: 24),
            _sectionDepenses(),
            const SizedBox(height: 24),
            _sectionResultat(resultat),
          ],
        ),
      ),
    );
  }

  Widget _banniereInfo() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Simulation uniquement : rien n\'est enregistré. Aucun '
                'chargement ni achat n\'est créé — entrez des prix et '
                'quantités envisagés pour estimer le coût de revient réel '
                'et la marge avant d\'acheter.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      );

  Widget _carte({required String titre, required Widget child, Widget? action}) {
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
              Expanded(child: Text(titre, style: AppTextStyles.h3)),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _sectionLignes() {
    return _carte(
      titre: 'Articles (${_lignes.length})',
      action: AppButton(
        label: 'Ajouter une ligne',
        icon: Icons.add_rounded,
        isOutlined: true,
        onPressed: _ajouterLigne,
      ),
      child: Column(
        children: [
          ArticleAutocompleteField(
            label: 'Préremplir depuis un pneu existant (ex : 55R16)',
            onSearch: (q) => ref.read(articleRepositoryProvider).searchArticles(q),
            onSelected: _ajouterLigneDepuisArticle,
          ),
          const SizedBox(height: 16),
          for (final l in _lignes) ...[
            _ligneRow(l),
            const Divider(height: 24),
          ],
          if (_lignes.isEmpty)
            const Text('Aucune ligne — ajoutez au moins un article.',
                style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _ligneRow(_LigneForm l) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: AppTextField(
            label: 'Article',
            controller: l.nomCtrl,
            hint: 'Ex : Pneu 205/55R16',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppTextField(
            label: 'Quantité',
            controller: l.quantiteCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppTextField(
            label: 'Prix achat unit. (FCFA)',
            controller: l.prixAchatCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppTextField(
            label: 'Poids unit. (kg, optionnel)',
            controller: l.poidsCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppTextField(
            label: 'Prix vente prévu (optionnel)',
            controller: l.prixVenteCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          tooltip: 'Supprimer cette ligne',
          onPressed: () => _supprimerLigne(l),
        ),
      ],
    );
  }

  Widget _sectionDepenses() {
    return _carte(
      titre: 'Dépenses partagées (${_depenses.length})',
      action: AppButton(
        label: 'Ajouter une dépense',
        icon: Icons.add_rounded,
        isOutlined: true,
        onPressed: _ajouterDepense,
      ),
      child: Column(
        children: [
          for (final d in _depenses) ...[
            _depenseRow(d),
            const Divider(height: 24),
          ],
          if (_depenses.isEmpty)
            const Text(
                'Aucune dépense (transport, douane, manutention...) — '
                'facultatif.',
                style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _depenseRow(_DepenseForm d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppTextField(
                label: 'Description',
                controller: d.descriptionCtrl,
                hint: 'Ex : Transport, douane...',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppTextField(
                label: 'Montant (FCFA)',
                controller: d.montantCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Répartition',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: d.methode,
                    items: const [
                      DropdownMenuItem(
                          value: 'quantite', child: Text('Par quantité')),
                      DropdownMenuItem(
                          value: 'valeur_achat',
                          child: Text('Par valeur d\'achat')),
                      DropdownMenuItem(value: 'poids', child: Text('Par poids')),
                      DropdownMenuItem(
                          value: 'directe',
                          child: Text('Directe (une seule ligne)')),
                    ],
                    onChanged: (v) =>
                        setState(() => d.methode = v ?? 'quantite'),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
              tooltip: 'Supprimer cette dépense',
              onPressed: () => _supprimerDepense(d),
            ),
          ],
        ),
        if (d.methode == 'directe') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int?>(
              initialValue: d.ligneCibleId,
              decoration: const InputDecoration(labelText: 'Ligne ciblée'),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Choisir une ligne')),
                ..._lignes.asMap().entries.map((e) => DropdownMenuItem(
                      value: e.value.id,
                      child: Text(e.value.nomCtrl.text.trim().isEmpty
                          ? 'Article ${e.key + 1}'
                          : e.value.nomCtrl.text.trim()),
                    )),
              ],
              onChanged: (v) => setState(() => d.ligneCibleId = v),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionResultat(SimulationResultat resultat) {
    return _carte(
      titre: 'Résultat de la simulation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (resultat.erreurs.isNotEmpty) ...[
            for (final e in resultat.erreurs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(e,
                    style:
                        const TextStyle(color: AppColors.warning, fontSize: 12)),
              ),
            const SizedBox(height: 8),
          ],
          if (resultat.lignes.isEmpty)
            const Text('Ajoutez au moins une ligne pour voir le résultat.',
                style: AppTextStyles.caption)
          else ...[
            _tableauResultat(resultat),
            const SizedBox(height: 16),
            _totaux(resultat),
          ],
        ],
      ),
    );
  }

  Widget _tableauResultat(SimulationResultat resultat) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Article')),
          DataColumn(label: Text('Qté'), numeric: true),
          DataColumn(label: Text('Prix achat'), numeric: true),
          DataColumn(label: Text('Part dépenses'), numeric: true),
          DataColumn(label: Text('Coût de revient unit.'), numeric: true),
          DataColumn(label: Text('Coût de revient total'), numeric: true),
          DataColumn(label: Text('Marge unit.'), numeric: true),
        ],
        rows: [
          for (final r in resultat.lignes)
            DataRow(cells: [
              DataCell(Text(r.ligne.articleNom)),
              DataCell(Text(r.ligne.quantite.toStringAsFixed(0))),
              DataCell(Text(CurrencyFormatter.format(r.ligne.prixAchatUnitaire))),
              DataCell(Text(CurrencyFormatter.format(r.partDepensesUnitaire))),
              DataCell(Text(CurrencyFormatter.format(r.coutRevientUnitaire),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(CurrencyFormatter.format(r.coutRevientTotal))),
              DataCell(Text(
                r.margeUnitaire != null
                    ? CurrencyFormatter.format(r.margeUnitaire!)
                    : '—',
                style: TextStyle(
                  color: r.margeUnitaire == null
                      ? AppColors.textSecondary
                      : r.margeUnitaire! >= 0
                          ? AppColors.success
                          : AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              )),
            ]),
        ],
      ),
    );
  }

  Widget _totaux(SimulationResultat resultat) {
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        _totalItem('Prix d\'achat total', resultat.prixAchatTotal),
        _totalItem('Dépenses totales', resultat.depensesTotal),
        _totalItem('Coût total', resultat.coutTotal, gras: true),
        if (resultat.depensesNonAllouees > 0.01)
          _totalItem('Dépenses non réparties', resultat.depensesNonAllouees,
              couleur: AppColors.warning),
      ],
    );
  }

  Widget _totalItem(String label, double montant,
      {bool gras = false, Color? couleur}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(
          CurrencyFormatter.format(montant),
          style: (gras ? AppTextStyles.bodyBold : AppTextStyles.body)
              .copyWith(color: couleur, fontSize: gras ? 16 : null),
        ),
      ],
    );
  }
}
