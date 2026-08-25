import '../entities/employee.dart';

abstract class PersonnelRepository {
  Future<List<JobPositionEntity>> getAllJobPositions();
  Future<int> createJobPosition(String nom);

  Future<List<EmployeeEntity>> getAllEmployees();
  Future<List<EmployeeEntity>> getActiveEmployees();
  Future<EmployeeEntity?> getEmployeeById(int id);
  Future<List<EmployeeEntity>> searchEmployees(String query);

  Future<int> createEmployee({
    required String nom,
    required String prenom,
    String? telephone,
    required int posteId,
    required DateTime dateEmbauche,
    String? typeContrat,
    double salaireBase = 0,
    String? notes,
    int? userId,
    int? createdById,
  });

  Future<void> updateEmployee(EmployeeEntity employee);

  Future<void> deactivateEmployee(int id, DateTime dateDepart);

  Future<List<EmployeeAbsenceEntity>> getAbsencesForEmployee(int employeeId);

  Future<int> createAbsence({
    required int employeeId,
    required DateTime dateDebut,
    required DateTime dateFin,
    required double nombreJours,
    required String motif,
    bool justifiee = true,
    bool avecRetenue = true,
    String? commentaire,
    required int userId,
  });

  Future<void> deleteAbsence(int id);
}
