class PayrollSettingsEntity {
  final double joursTheoriquesParMois;
  final DateTime? dateModification;

  const PayrollSettingsEntity({
    this.joursTheoriquesParMois = 30,
    this.dateModification,
  });
}

class PayrollPeriodEntity {
  final int id;
  final String libelle;
  final DateTime dateDebut;
  final DateTime dateFin;

  /// 'ouverte' | 'cloturee'
  final String statut;
  final DateTime dateCreation;

  const PayrollPeriodEntity({
    required this.id,
    required this.libelle,
    required this.dateDebut,
    required this.dateFin,
    this.statut = 'ouverte',
    required this.dateCreation,
  });
}

class PayslipEntity {
  final int id;
  final int payrollPeriodId;
  final int employeeId;
  final String? employeeNomComplet;

  final double salaireBase;
  final double joursTheoriques;
  final double joursAbsence;
  final double retenueAbsence;
  final double avancesDeduites;
  final double bonus;
  final double autresDeductions;
  final double ajustementManuel;
  final String? justificationAjustement;

  final double salaireNet;
  final double montantPaye;

  /// 'non_paye' | 'partiel' | 'paye'
  final String statutPaiement;
  final DateTime dateCreation;

  const PayslipEntity({
    required this.id,
    required this.payrollPeriodId,
    required this.employeeId,
    this.employeeNomComplet,
    required this.salaireBase,
    required this.joursTheoriques,
    this.joursAbsence = 0,
    this.retenueAbsence = 0,
    this.avancesDeduites = 0,
    this.bonus = 0,
    this.autresDeductions = 0,
    this.ajustementManuel = 0,
    this.justificationAjustement,
    required this.salaireNet,
    this.montantPaye = 0,
    this.statutPaiement = 'non_paye',
    required this.dateCreation,
  });

  double get resteAPayer => salaireNet - montantPaye;
}

class PayslipPaymentEntity {
  final int id;
  final int payslipId;
  final double montant;
  final DateTime datePaiement;
  final String modePaiement;
  final int payeParUserId;
  final String? payeParUserNom;
  final DateTime dateCreation;

  const PayslipPaymentEntity({
    required this.id,
    required this.payslipId,
    required this.montant,
    required this.datePaiement,
    required this.modePaiement,
    required this.payeParUserId,
    this.payeParUserNom,
    required this.dateCreation,
  });
}

class SalaryAdvanceEntity {
  final int id;
  final int employeeId;
  final double montant;
  final DateTime date;
  final String? motif;

  /// 'active' | 'consommee' | 'annulee'
  final String statut;
  final int? payslipId;
  final int userId;
  final DateTime dateCreation;

  const SalaryAdvanceEntity({
    required this.id,
    required this.employeeId,
    required this.montant,
    required this.date,
    this.motif,
    this.statut = 'active',
    this.payslipId,
    required this.userId,
    required this.dateCreation,
  });
}
