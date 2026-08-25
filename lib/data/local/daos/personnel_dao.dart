import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/employees_table.dart';
import '../tables/job_positions_table.dart';
import '../tables/employee_absences_table.dart';

part 'personnel_dao.g.dart';

@DriftAccessor(tables: [Employees, JobPositions, EmployeeAbsences])
class PersonnelDao extends DatabaseAccessor<AppDatabase>
    with _$PersonnelDaoMixin {
  PersonnelDao(super.db);

  // ── Postes ────────────────────────────────────────────────────────────────

  Future<List<JobPosition>> getAllJobPositions() =>
      (select(jobPositions)..where((p) => p.actif.equals(true))).get();

  Future<int> createJobPosition(JobPositionsCompanion poste) =>
      into(jobPositions).insert(poste);

  // ── Employés ──────────────────────────────────────────────────────────────

  Future<List<Employee>> getAllEmployees() => select(employees).get();

  Future<List<Employee>> getActiveEmployees() =>
      (select(employees)..where((e) => e.statut.equals('actif'))).get();

  Future<Employee?> getEmployeeById(int id) =>
      (select(employees)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<List<Employee>> searchEmployees(String query) {
    final likeQuery = '%$query%';
    return (select(employees)
          ..where((e) => e.nom.like(likeQuery) | e.prenom.like(likeQuery)))
        .get();
  }

  Future<int> createEmployee(EmployeesCompanion employee) =>
      into(employees).insert(employee);

  /// Mise à jour ciblée (pas de `.replace()`) : seuls les champs
  /// fournis sont modifiés, ce qui préserve `created_by_id` et
  /// `date_creation` sans avoir à les faire transiter par l'appelant.
  Future<void> updateEmployee(int id, EmployeesCompanion changes) =>
      (update(employees)..where((e) => e.id.equals(id))).write(changes);

  /// Un employé n'est jamais supprimé (historique paie/absences à
  /// conserver) : on le désactive.
  Future<void> deactivateEmployee(int id, DateTime dateDepart) =>
      (update(employees)..where((e) => e.id.equals(id))).write(
        EmployeesCompanion(
          statut: const Value('inactif'),
          dateDepart: Value(dateDepart),
        ),
      );

  // ── Absences ──────────────────────────────────────────────────────────────

  Future<List<EmployeeAbsence>> getAbsencesForEmployee(int employeeId) =>
      (select(employeeAbsences)
            ..where((a) => a.employeeId.equals(employeeId))
            ..orderBy([(a) => OrderingTerm.desc(a.dateDebut)]))
          .get();

  /// Absences avec retenue d'un employé qui chevauchent la période
  /// [debut, fin] (bornes incluses), utilisées pour le calcul de paie.
  Future<List<EmployeeAbsence>> getAbsencesAvecRetenueDansPeriode({
    required int employeeId,
    required DateTime debut,
    required DateTime fin,
  }) =>
      (select(employeeAbsences)
            ..where((a) =>
                a.employeeId.equals(employeeId) &
                a.avecRetenue.equals(true) &
                a.dateDebut.isSmallerOrEqualValue(fin) &
                a.dateFin.isBiggerOrEqualValue(debut)))
          .get();

  Future<int> createAbsence(EmployeeAbsencesCompanion absence) =>
      into(employeeAbsences).insert(absence);

  Future<bool> updateAbsence(EmployeeAbsence absence) =>
      update(employeeAbsences).replace(absence);

  Future<int> deleteAbsence(int id) =>
      (delete(employeeAbsences)..where((a) => a.id.equals(id))).go();
}
