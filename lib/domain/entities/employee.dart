/// Entité employé (module Personnel).
class EmployeeEntity {
  final int id;
  final String nom;
  final String prenom;
  final String? telephone;
  final int posteId;
  final String? posteNom;
  final DateTime dateEmbauche;
  final String? typeContrat;
  final double salaireBase;

  /// 'actif' | 'inactif'
  final String statut;
  final DateTime? dateDepart;
  final String? notes;
  final int? userId;
  final DateTime dateCreation;

  const EmployeeEntity({
    required this.id,
    required this.nom,
    required this.prenom,
    this.telephone,
    required this.posteId,
    this.posteNom,
    required this.dateEmbauche,
    this.typeContrat,
    this.salaireBase = 0,
    this.statut = 'actif',
    this.dateDepart,
    this.notes,
    this.userId,
    required this.dateCreation,
  });

  bool get estActif => statut == 'actif';
  String get nomComplet => '$prenom $nom';
}

class JobPositionEntity {
  final int id;
  final String nom;
  final bool actif;

  const JobPositionEntity({
    required this.id,
    required this.nom,
    this.actif = true,
  });
}

class EmployeeAbsenceEntity {
  final int id;
  final int employeeId;
  final DateTime dateDebut;
  final DateTime dateFin;
  final double nombreJours;
  final String motif;
  final bool justifiee;
  final bool avecRetenue;
  final String? commentaire;
  final int userId;
  final DateTime dateCreation;

  const EmployeeAbsenceEntity({
    required this.id,
    required this.employeeId,
    required this.dateDebut,
    required this.dateFin,
    required this.nombreJours,
    required this.motif,
    this.justifiee = true,
    this.avecRetenue = true,
    this.commentaire,
    required this.userId,
    required this.dateCreation,
  });
}
