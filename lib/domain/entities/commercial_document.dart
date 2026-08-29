import 'document_type.dart';

class TvaRateEntity {
  final int id;
  final double taux;
  final String libelle;
  final bool actif;

  const TvaRateEntity({
    required this.id,
    required this.taux,
    required this.libelle,
    required this.actif,
  });
}

class DocumentLigneEntity {
  final int id;
  final int documentId;
  final int articleId;
  final String articleCode;
  final String articleNom;
  final double quantite;
  final double prixUnitaireHt;
  final double tauxTva;
  final double remiseLignePct;
  final double totalHt;
  final double montantTva;
  final double totalTtc;
  final int position;
  final String? notesLigne;

  /// Commission commerciale (interne — jamais affichée sur la facture
  /// client, voir [PrintableDocument] qui n'expose pas ce champ).
  final double? commissionUnitaire;
  final double? commissionMontant;
  final int? commissionSettlementId;

  /// Promotion dont le prix a été préremplié automatiquement sur cette
  /// ligne au moment de la vente — voir [DocumentLinesEditor]. Null si
  /// la ligne n'est pas issue d'une promotion.
  final int? promotionId;

  const DocumentLigneEntity({
    required this.id,
    required this.documentId,
    required this.articleId,
    required this.articleCode,
    required this.articleNom,
    required this.quantite,
    required this.prixUnitaireHt,
    required this.tauxTva,
    required this.remiseLignePct,
    required this.totalHt,
    required this.montantTva,
    required this.totalTtc,
    required this.position,
    this.notesLigne,
    this.commissionUnitaire,
    this.commissionMontant,
    this.commissionSettlementId,
    this.promotionId,
  });
}

class DocumentPaiementEntity {
  final int id;
  final int documentId;
  final double montant;
  final DateTime datePaiement;
  final String modePaiement;
  final String? reference;
  final int? avoirDocumentId;
  final String? createdByNom;
  final DateTime dateCreation;

  const DocumentPaiementEntity({
    required this.id,
    required this.documentId,
    required this.montant,
    required this.datePaiement,
    required this.modePaiement,
    this.reference,
    this.avoirDocumentId,
    this.createdByNom,
    required this.dateCreation,
  });
}

class DocumentHistoriqueEntity {
  final int id;
  final int documentId;
  final String action;
  final String? ancienStatut;
  final String? nouveauStatut;
  final String? description;
  final int? userId;
  final String? userNom;
  final DateTime dateAction;

  const DocumentHistoriqueEntity({
    required this.id,
    required this.documentId,
    required this.action,
    this.ancienStatut,
    this.nouveauStatut,
    this.description,
    this.userId,
    this.userNom,
    required this.dateAction,
  });
}

class DocumentEntity {
  final int id;
  final String numero;
  final DocumentType type;
  final DocumentStatut statut;
  final int? clientId;
  final String? clientNom;
  final String? clientNif;
  final int storeId;
  final String? storeNom;
  final DateTime dateDocument;
  final DateTime dateCreation;
  final DateTime? dateModification;
  final DateTime? dateValidation;
  final DateTime? dateEcheance;
  final int? createdById;
  final String? createdByNom;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final double remiseGlobalePct;
  final double montantPaye;
  final String statutPaiement;
  final int? parentDocumentId;
  final String? notes;
  final String? referenceExterne;
  final String? conditionsReglement;
  final List<DocumentLigneEntity> lignes;
  final List<DocumentPaiementEntity> paiements;

  /// Commercial (employé) attribué à cette vente — interne uniquement.
  final int? vendeurEmployeeId;
  final String? vendeurNom;

  const DocumentEntity({
    required this.id,
    required this.numero,
    required this.type,
    required this.statut,
    this.clientId,
    this.clientNom,
    this.clientNif,
    required this.storeId,
    this.storeNom,
    required this.dateDocument,
    required this.dateCreation,
    this.dateModification,
    this.dateValidation,
    this.dateEcheance,
    this.createdById,
    this.createdByNom,
    required this.totalHt,
    required this.totalTva,
    required this.totalTtc,
    required this.remiseGlobalePct,
    required this.montantPaye,
    required this.statutPaiement,
    this.parentDocumentId,
    this.notes,
    this.referenceExterne,
    this.conditionsReglement,
    this.lignes = const [],
    this.paiements = const [],
    this.vendeurEmployeeId,
    this.vendeurNom,
  });

  double get resteAPayer => totalTtc - montantPaye;
  bool get estPaye => statutPaiement == 'paye';
  bool get estModifiable => statut.estModifiable;
  bool get estAnnule => statut == DocumentStatut.annule;
}
