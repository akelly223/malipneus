/// Une ligne d'achat hypothétique du simulateur (pas encore un vrai
/// achat) : un article, une quantité, un prix d'achat envisagé.
class SimulationLigne {
  final String articleNom;
  final double quantite;
  final double prixAchatUnitaire;

  /// Poids unitaire (kg), requis seulement si une dépense est répartie
  /// "par poids".
  final double? poidsUnitaire;

  /// Prix de vente envisagé — optionnel, sert uniquement à afficher une
  /// marge estimée si renseigné.
  final double? prixVenteUnitaire;

  const SimulationLigne({
    required this.articleNom,
    required this.quantite,
    required this.prixAchatUnitaire,
    this.poidsUnitaire,
    this.prixVenteUnitaire,
  });
}

/// Une dépense hypothétique (transport, douane, manutention...) à
/// répartir sur les lignes ci-dessus.
class SimulationDepense {
  final String description;
  final double montant;

  /// 'quantite' | 'valeur_achat' | 'poids' | 'directe'
  final String methodeAllocation;

  /// Index (dans la liste de lignes) ciblé, uniquement pour
  /// methodeAllocation == 'directe' (dépense propre à une seule ligne,
  /// jamais partagée).
  final int? ligneCibleIndex;

  const SimulationDepense({
    required this.description,
    required this.montant,
    required this.methodeAllocation,
    this.ligneCibleIndex,
  });
}

class SimulationLigneResultat {
  final SimulationLigne ligne;
  final double partDepensesUnitaire;
  final double coutRevientUnitaire;
  final double coutRevientTotal;
  final double? margeUnitaire;
  final double? margeTotale;

  const SimulationLigneResultat({
    required this.ligne,
    required this.partDepensesUnitaire,
    required this.coutRevientUnitaire,
    required this.coutRevientTotal,
    this.margeUnitaire,
    this.margeTotale,
  });
}

class SimulationResultat {
  final List<SimulationLigneResultat> lignes;
  final double prixAchatTotal;
  final double depensesTotal;
  final double depensesNonAllouees;
  final double coutTotal;
  final List<String> erreurs;

  const SimulationResultat({
    required this.lignes,
    required this.prixAchatTotal,
    required this.depensesTotal,
    required this.depensesNonAllouees,
    required this.coutTotal,
    required this.erreurs,
  });
}

/// Simule le coût de revient réel par article d'un futur chargement,
/// AVANT tout achat réel — aucune lecture ni écriture en base. Reproduit
/// volontairement le même principe de répartition que
/// [LoadingCostAllocationService] (utilisé une fois le chargement
/// réellement créé), pour que la simulation et la réalité coïncident.
class LoadingSimulationService {
  LoadingSimulationService._();

  static SimulationResultat simuler({
    required List<SimulationLigne> lignes,
    required List<SimulationDepense> depenses,
  }) {
    if (lignes.isEmpty) {
      return const SimulationResultat(
        lignes: [],
        prixAchatTotal: 0,
        depensesTotal: 0,
        depensesNonAllouees: 0,
        coutTotal: 0,
        erreurs: [],
      );
    }

    final quantiteTotale = lignes.fold<double>(0, (s, l) => s + l.quantite);
    final valeurTotale =
        lignes.fold<double>(0, (s, l) => s + l.quantite * l.prixAchatUnitaire);
    final prixAchatTotal = valeurTotale;
    final depensesTotal = depenses.fold<double>(0, (s, d) => s + d.montant);

    final partParLigne = List<double>.filled(lignes.length, 0);
    double depensesNonAllouees = 0;
    final erreurs = <String>[];

    for (final d in depenses) {
      switch (d.methodeAllocation) {
        case 'directe':
          final i = d.ligneCibleIndex;
          if (i == null || i < 0 || i >= lignes.length) {
            depensesNonAllouees += d.montant;
            erreurs.add(
                'Dépense directe "${d.description}" : aucune ligne cible sélectionnée.');
            continue;
          }
          partParLigne[i] += d.montant;
          break;

        case 'poids':
          final sansPoids = lignes
              .where((l) => l.poidsUnitaire == null)
              .map((l) => l.articleNom)
              .toList();
          if (sansPoids.isNotEmpty) {
            depensesNonAllouees += d.montant;
            erreurs.add(
                'Répartition par poids impossible pour "${d.description}" : '
                'poids manquant pour ${sansPoids.join(', ')}.');
            continue;
          }
          final poidsTotal = lignes.fold<double>(
              0, (s, l) => s + l.quantite * (l.poidsUnitaire ?? 0));
          if (poidsTotal <= 0) {
            depensesNonAllouees += d.montant;
            continue;
          }
          for (var i = 0; i < lignes.length; i++) {
            final poidsLigne = lignes[i].quantite * (lignes[i].poidsUnitaire ?? 0);
            partParLigne[i] += d.montant * poidsLigne / poidsTotal;
          }
          break;

        case 'valeur_achat':
          if (valeurTotale <= 0) {
            depensesNonAllouees += d.montant;
            continue;
          }
          for (var i = 0; i < lignes.length; i++) {
            final valeurLigne = lignes[i].quantite * lignes[i].prixAchatUnitaire;
            partParLigne[i] += d.montant * valeurLigne / valeurTotale;
          }
          break;

        case 'quantite':
        default:
          if (quantiteTotale <= 0) {
            depensesNonAllouees += d.montant;
            continue;
          }
          for (var i = 0; i < lignes.length; i++) {
            partParLigne[i] += d.montant * lignes[i].quantite / quantiteTotale;
          }
      }
    }

    final resultatLignes = <SimulationLigneResultat>[];
    for (var i = 0; i < lignes.length; i++) {
      final l = lignes[i];
      final partUnitaire = l.quantite > 0 ? partParLigne[i] / l.quantite : 0.0;
      final coutRevientUnitaire = l.prixAchatUnitaire + partUnitaire;
      final coutRevientTotal = coutRevientUnitaire * l.quantite;
      final margeUnitaire =
          l.prixVenteUnitaire != null ? l.prixVenteUnitaire! - coutRevientUnitaire : null;
      resultatLignes.add(SimulationLigneResultat(
        ligne: l,
        partDepensesUnitaire: partUnitaire,
        coutRevientUnitaire: coutRevientUnitaire,
        coutRevientTotal: coutRevientTotal,
        margeUnitaire: margeUnitaire,
        margeTotale: margeUnitaire != null ? margeUnitaire * l.quantite : null,
      ));
    }

    return SimulationResultat(
      lignes: resultatLignes,
      prixAchatTotal: prixAchatTotal,
      depensesTotal: depensesTotal,
      depensesNonAllouees: depensesNonAllouees,
      coutTotal: prixAchatTotal + depensesTotal,
      erreurs: erreurs,
    );
  }
}
