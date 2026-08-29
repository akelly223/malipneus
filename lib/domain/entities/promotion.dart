/// Type de remise appliquée par une promotion.
enum PromotionType {
  pourcentage,
  montant;

  static PromotionType fromDb(String value) =>
      value == 'montant' ? PromotionType.montant : PromotionType.pourcentage;

  String toDb() => this == PromotionType.montant ? 'montant' : 'pourcentage';
}

/// Statut d'affichage d'une promotion, dérivé de [actif] et de la
/// période — n'est jamais stocké, toujours recalculé à la lecture.
enum PromotionStatut { active, planifiee, expiree, inactive }

/// Promotion commerciale : remise (pourcentage ou montant fixe)
/// appliquée automatiquement au prix de vente d'un ou plusieurs pneus
/// pendant une période donnée.
class PromotionEntity {
  final int id;
  final String nom;
  final PromotionType type;
  final double valeur;
  final DateTime dateDebut;
  final DateTime dateFin;
  final bool actif;
  final DateTime dateCreation;

  /// Ids des pneus couverts par cette promotion.
  final List<int> articleIds;

  /// Libellés des pneus couverts ("code — nom"), pour affichage — vide
  /// si non chargés par l'appelant.
  final List<String> articlesLibelles;

  const PromotionEntity({
    required this.id,
    required this.nom,
    required this.type,
    required this.valeur,
    required this.dateDebut,
    required this.dateFin,
    required this.actif,
    required this.dateCreation,
    this.articleIds = const [],
    this.articlesLibelles = const [],
  });

  bool estEnCoursA(DateTime moment) =>
      actif && !moment.isBefore(dateDebut) && !moment.isAfter(dateFin);

  bool get estEnCours => estEnCoursA(DateTime.now());

  PromotionStatut get statut {
    if (!actif) return PromotionStatut.inactive;
    final now = DateTime.now();
    if (now.isBefore(dateDebut)) return PromotionStatut.planifiee;
    if (now.isAfter(dateFin)) return PromotionStatut.expiree;
    return PromotionStatut.active;
  }

  /// Prix obtenu après application de la remise à [prixVente], jamais
  /// négatif.
  double prixPromo(double prixVente) {
    final prix = type == PromotionType.pourcentage
        ? prixVente * (1 - valeur / 100)
        : prixVente - valeur;
    return prix < 0 ? 0 : prix;
  }

  /// Remise équivalente en pourcentage de [prixVente] — utilisé pour
  /// préremplir le champ "Remise %" existant d'une ligne de vente, quel
  /// que soit le type de promotion (pourcentage ou montant fixe).
  double remisePourcentageDe(double prixVente) {
    if (type == PromotionType.pourcentage) {
      return valeur.clamp(0, 100).toDouble();
    }
    if (prixVente <= 0) return 0;
    final pct = (valeur / prixVente) * 100;
    return pct.clamp(0, 100).toDouble();
  }
}

/// Performance réelle d'une promotion, mesurée sur les ventes
/// effectivement enregistrées (jamais une estimation) : combien de
/// pneus vendus pendant la promotion, quel chiffre d'affaires réalisé,
/// et combien de marge cette remise a coûté par rapport à une vente au
/// prix normal.
class PromotionPerformanceEntity {
  final int promotionId;
  final double quantiteVendue;
  final int nombreVentes;

  /// Chiffre d'affaires HT réellement encaissé sur ces lignes (déjà net
  /// de la remise promo).
  final double chiffreAffaires;

  /// Manque à gagner en FCFA = ce que la remise a coûté. Équivaut
  /// exactement à la marge perdue : le coût du pneu ne change pas avec
  /// la promo, donc chaque FCFA de remise est un FCFA de marge en
  /// moins.
  final double remiseAccordee;

  /// Marge qui aurait été réalisée sur ces mêmes ventes au prix normal
  /// (estimée à partir du prix de revient réel de chaque pneu, ou du
  /// prix d'achat si aucun lot de stock n'est disponible).
  final double margeNormaleEstimee;

  /// Marge réellement réalisée avec la promotion = [margeNormaleEstimee]
  /// − [remiseAccordee].
  final double margeReelle;

  const PromotionPerformanceEntity({
    required this.promotionId,
    required this.quantiteVendue,
    required this.nombreVentes,
    required this.chiffreAffaires,
    required this.remiseAccordee,
    required this.margeNormaleEstimee,
    required this.margeReelle,
  });

  /// Part de la marge normale perdue à cause de la promotion, en %.
  double get pourcentageMargePerdue => margeNormaleEstimee <= 0
      ? 0
      : (remiseAccordee / margeNormaleEstimee * 100).clamp(0, 100).toDouble();
}
