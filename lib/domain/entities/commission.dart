/// Configuration de rémunération commerciale d'un employé.
class CommissionConfigEntity {
  final int id;
  final int employeeId;

  /// 'fixe' | 'pourcentage'
  final String typeCommission;
  final double? montantFixeParPneu;
  final double? pourcentage;
  final DateTime dateCreation;
  final DateTime? dateModification;

  const CommissionConfigEntity({
    required this.id,
    required this.employeeId,
    required this.typeCommission,
    this.montantFixeParPneu,
    this.pourcentage,
    required this.dateCreation,
    this.dateModification,
  });

  bool get estFixe => typeCommission == 'fixe';

  /// Calcule la commission pour une ligne de vente donnée.
  double calculerCommission({
    required double quantite,
    required double totalLigneHt,
  }) {
    if (estFixe) return (montantFixeParPneu ?? 0) * quantite;
    return totalLigneHt * (pourcentage ?? 0) / 100;
  }
}

/// Résumé des commissions dues à un commercial sur une période, avant
/// règlement (calculé en direct depuis les ventes non réglées, pas
/// stocké — voir [CommissionSettlementEntity]).
class CommissionsDuesEntity {
  final int employeeId;
  final DateTime periodeDebut;
  final DateTime periodeFin;
  final int nombreVentes;
  final double quantiteTotale;
  final double montantVentesTotal;
  final double montantCommission;

  const CommissionsDuesEntity({
    required this.employeeId,
    required this.periodeDebut,
    required this.periodeFin,
    this.nombreVentes = 0,
    this.quantiteTotale = 0,
    this.montantVentesTotal = 0,
    this.montantCommission = 0,
  });
}

/// Une ligne de vente commissionnée, avec le détail nécessaire pour
/// justifier une commission (client, date, article, montant) — sert
/// à la fois à l'affichage "détail des ventes" et à l'export PDF de
/// preuve (dû ou déjà réglé).
class CommissionLigneDetailEntity {
  final int documentLineId;
  final int documentId;
  final String documentNumero;
  final DateTime dateDocument;

  /// Null pour une vente comptoir sans client enregistré.
  final String? clientNom;
  final String articleNom;
  final double quantite;
  final double totalLigneHt;
  final double commissionMontant;

  const CommissionLigneDetailEntity({
    required this.documentLineId,
    required this.documentId,
    required this.documentNumero,
    required this.dateDocument,
    this.clientNom,
    required this.articleNom,
    required this.quantite,
    required this.totalLigneHt,
    required this.commissionMontant,
  });
}

/// Règlement effectué de commissions commerciales (historique immuable).
class CommissionSettlementEntity {
  final int id;
  final int employeeId;
  final String? employeeNomComplet;
  final DateTime periodeDebut;
  final DateTime periodeFin;
  final int nombreVentes;
  final double quantiteTotale;
  final double montantVentesTotal;
  final double montantCommission;
  final DateTime datePaiement;
  final String modePaiement;
  final int payeParUserId;
  final String? payeParUserNom;
  final DateTime dateCreation;
  final String? notes;

  const CommissionSettlementEntity({
    required this.id,
    required this.employeeId,
    this.employeeNomComplet,
    required this.periodeDebut,
    required this.periodeFin,
    this.nombreVentes = 0,
    this.quantiteTotale = 0,
    this.montantVentesTotal = 0,
    this.montantCommission = 0,
    required this.datePaiement,
    required this.modePaiement,
    required this.payeParUserId,
    this.payeParUserNom,
    required this.dateCreation,
    this.notes,
  });
}
