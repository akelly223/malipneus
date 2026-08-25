class LoadingEntity {
  final int id;
  final String numero;

  /// Nom choisi par l'utilisateur (ex: "Chargement Awa"), distinct du
  /// [numero] auto-généré. Fortement recommandé, pas obligatoire.
  final String? nom;

  final int? supplierId;
  final String? supplierNom;
  final DateTime dateChargement;

  /// Date d'arrivée effective (dédouanement/réception), null tant que
  /// le chargement n'est pas arrivé.
  final DateTime? dateArrivee;

  /// Numéro de container, si applicable (transport maritime).
  final String? container;

  /// Référence libre (bon de commande fournisseur, dossier transitaire...).
  final String? reference;

  final String? notes;

  /// 'ouvert' | 'cloture'
  final String statut;
  final int? createdById;
  final String? createdByNom;
  final DateTime dateCreation;

  const LoadingEntity({
    required this.id,
    required this.numero,
    this.nom,
    this.supplierId,
    this.supplierNom,
    required this.dateChargement,
    this.dateArrivee,
    this.container,
    this.reference,
    this.notes,
    this.statut = 'ouvert',
    this.createdById,
    this.createdByNom,
    required this.dateCreation,
  });

  /// Nom si renseigné, sinon le numéro auto-généré — toujours affichable.
  String get nomAffiche => (nom != null && nom!.trim().isNotEmpty) ? nom! : numero;
}

/// Rentabilité d'une ligne d'achat (un article, à un prix d'achat et une
/// part de dépenses qui lui sont propres) au sein d'un chargement —
/// niveau "détail" par opposition à la synthèse globale du chargement.
class ArticleRentabiliteLigne {
  final int purchaseItemId;
  final int articleId;
  final String articleNom;

  final double quantite;
  final double prixAchatUnitaire;

  /// Part des dépenses (directes + partagées) attribuée à CETTE ligne,
  /// par unité — jamais une moyenne globale du chargement.
  final double partDepensesUnitaire;

  /// Prix de revient réel de cette ligne = prixAchatUnitaire +
  /// partDepensesUnitaire.
  final double coutRevientUnitaire;

  /// Prix de vente actuel de l'article (indicatif, pas une moyenne des
  /// ventes réalisées).
  final double prixVenteUnitaire;

  final double margeUnitaire;
  final double margeTotale;

  const ArticleRentabiliteLigne({
    required this.purchaseItemId,
    required this.articleId,
    required this.articleNom,
    required this.quantite,
    required this.prixAchatUnitaire,
    required this.partDepensesUnitaire,
    required this.coutRevientUnitaire,
    required this.prixVenteUnitaire,
    required this.margeUnitaire,
    required this.margeTotale,
  });
}

/// Rentabilité complète d'un chargement (section 15).
class LoadingRentabiliteEntity {
  final int loadingId;

  // ── Stock ──────────────────────────────────────────────────────────────
  final double quantiteRecue;
  final double quantiteVendue;
  final double quantiteRestante;
  final double pertes;
  final double ajustements;

  // ── Coûts ──────────────────────────────────────────────────────────────
  final double prixAchatTotal;
  final double depensesTotal;
  final double coutTotal;
  final double prixRevientUnitaire;

  // ── Ventes ─────────────────────────────────────────────────────────────
  final double chiffreAffaires;
  final double prixVenteMoyen;

  // ── Rentabilité ────────────────────────────────────────────────────────
  final double coutDesProduitsVendus;
  final double margeBrute;
  final double commissionsCommerciales;
  final double beneficeEstime;

  // ── Détail par article (niveau 1) ─────────────────────────────────────
  // Les champs ci-dessus restent la vision globale (niveau 2) — aucun des
  // deux niveaux ne remplace l'autre.

  /// Rentabilité ligne d'achat par ligne d'achat — le vrai coût de
  /// chaque article, jamais une moyenne. Vide si le chargement n'a
  /// encore aucun achat.
  final List<ArticleRentabiliteLigne> lignes;

  /// Montant de dépenses qui n'a pas pu être réparti (ex: dépense
  /// directe sur un article sans ligne d'achat dans ce chargement, ou
  /// dépense "par poids" bloquée par un poids manquant) — inclus dans
  /// [depensesTotal]/[coutTotal] mais absent de [lignes]/[prixRevientUnitaire]
  /// tant qu'il reste non résolu.
  final double depensesNonAllouees;

  /// Messages explicites (ex: liste des articles sans poids renseigné)
  /// quand une répartition n'a pas pu être appliquée intégralement.
  final List<String> erreursAllocation;

  const LoadingRentabiliteEntity({
    required this.loadingId,
    this.quantiteRecue = 0,
    this.quantiteVendue = 0,
    this.quantiteRestante = 0,
    this.pertes = 0,
    this.ajustements = 0,
    this.prixAchatTotal = 0,
    this.depensesTotal = 0,
    this.coutTotal = 0,
    this.prixRevientUnitaire = 0,
    this.chiffreAffaires = 0,
    this.prixVenteMoyen = 0,
    this.coutDesProduitsVendus = 0,
    this.margeBrute = 0,
    this.commissionsCommerciales = 0,
    this.beneficeEstime = 0,
    this.lignes = const [],
    this.depensesNonAllouees = 0,
    this.erreursAllocation = const [],
  });
}
