/// Entité article — un pneu (produit vendu). [stockTotal] est la somme
/// du stock sur tous les magasins, [stockMinimum] déclenche l'alerte de
/// stock faible.
class ArticleEntity {
  final int id;
  final String code;
  final String nom;
  final int? categorieId;
  final String? categorieNom;
  final double prixAchat;
  final double prixVente;
  final double stockMinimum;
  final double stockTotal;
  final DateTime dateCreation;
  final bool actif;
  final double tauxTvaDefaut;

  /// Description libre optionnelle (notes, détails produit...).
  final String? description;

  // ── Caractéristiques pneu ──────────────────────────────────────────

  final String? marque;

  /// Libellé de dimension complet (ex: "195/65 R15").
  final String? dimension;

  /// Largeur en mm.
  final double? largeur;

  /// Hauteur/profil en % de la largeur.
  final double? hauteur;

  /// Diamètre de la jante en pouces.
  final double? diametre;

  /// Type de véhicule visé (tourisme, camionnette, poids lourd, moto,
  /// agricole, génie civil...).
  final String? type;

  /// Saison (été, hiver, toutes saisons), si applicable.
  final String? saison;

  /// État du pneu : 'neuf' (défaut), 'occasion', 'rechape'.
  final String etat;

  /// Poids unitaire (kg), optionnel — utilisé uniquement pour la
  /// répartition des dépenses partagées d'un chargement "par poids".
  final double? poids;

  /// Chargement dont provient le stock le plus récent de cette
  /// référence (utilisé pour retrouver son prix de revient réel).
  final int? chargementOrigineId;
  final String? chargementOrigineNumero;

  /// Prix de revient réel : moyenne pondérée par la quantité restante
  /// des lots de stock encore disponibles de cet article (achat + part
  /// des dépenses qui lui a été attribuée), tous chargements confondus
  /// — distinct de [prixAchat] qui n'est que le dernier prix payé au
  /// fournisseur. Null si aucun lot de stock disponible.
  final double? prixRevient;

  const ArticleEntity({
    required this.id,
    required this.code,
    required this.nom,
    this.categorieId,
    this.categorieNom,
    required this.prixAchat,
    required this.prixVente,
    required this.stockMinimum,
    required this.stockTotal,
    required this.dateCreation,
    required this.actif,
    this.tauxTvaDefaut = 18,
    this.description,
    this.marque,
    this.dimension,
    this.largeur,
    this.hauteur,
    this.diametre,
    this.type,
    this.saison,
    this.etat = 'neuf',
    this.poids,
    this.chargementOrigineId,
    this.chargementOrigineNumero,
    this.prixRevient,
  });

  /// Stock totalement épuisé (0 unité).
  bool get estEnRuptureTotale => stockTotal <= 0;

  /// Stock sous le seuil minimum mais pas encore épuisé.
  bool get estEnAlerteFaible => !estEnRuptureTotale && stockTotal <= stockMinimum;

  /// Conservé pour compatibilité : vrai dès que le stock atteint ou
  /// passe sous le seuil minimum (faible OU rupture).
  bool get enRupture => stockTotal <= stockMinimum;

  /// Niveau d'alerte : 'rupture' | 'faible' | 'normal'.
  String get niveauAlerte {
    if (estEnRuptureTotale) return 'rupture';
    if (estEnAlerteFaible) return 'faible';
    return 'normal';
  }

  double get margeUnitaire => prixVente - prixAchat;

  /// Libellé de dimension à afficher : [dimension] si renseigné, sinon
  /// reconstruit à partir de largeur/hauteur/diamètre si disponibles.
  String? get dimensionAffichee {
    if (dimension != null && dimension!.isNotEmpty) return dimension;
    if (largeur != null && hauteur != null && diametre != null) {
      return '${largeur!.toStringAsFixed(0)}/${hauteur!.toStringAsFixed(0)} '
          'R${diametre!.toStringAsFixed(0)}';
    }
    return null;
  }
}
