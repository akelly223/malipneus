class ExpenseCategoryEntity {
  final int id;
  final String nom;
  final bool actif;

  const ExpenseCategoryEntity({
    required this.id,
    required this.nom,
    this.actif = true,
  });
}

class ExpenseEntity {
  final int id;
  final int categorieId;
  final String? categorieNom;
  final double montant;
  final DateTime date;
  final String? description;
  final String? fournisseurOuPersonne;
  final int? chargementId;
  final String? chargementNumero;
  final int? articleId;
  final String? articleNom;

  /// Méthode de répartition entre les lignes d'achat du chargement, si
  /// cette dépense est PARTAGÉE (articleId null, chargementId non null) :
  /// 'quantite' | 'valeur_achat' | 'poids' | 'manuelle'.
  final String methodeAllocation;

  final String? pieceJustificativePath;
  final int? createdById;
  final String? createdByNom;
  final DateTime dateCreation;

  const ExpenseEntity({
    required this.id,
    required this.categorieId,
    this.categorieNom,
    required this.montant,
    required this.date,
    this.description,
    this.fournisseurOuPersonne,
    this.chargementId,
    this.chargementNumero,
    this.articleId,
    this.articleNom,
    this.methodeAllocation = 'quantite',
    this.pieceJustificativePath,
    this.createdById,
    this.createdByNom,
    required this.dateCreation,
  });

  /// true si cette dépense est directement liée à un article précis
  /// (100% de son coût lui est attribué), false si elle est partagée
  /// entre tous les articles du chargement.
  bool get estDirecte => articleId != null;
}
