import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/personnel_repository.dart';

class PersonnelRepositoryImpl implements PersonnelRepository {
  final AppDatabase db;

  PersonnelRepositoryImpl(this.db);

  Future<EmployeeEntity> _toEntity(
    Employee e,
    Map<int, String> postesParId,
  ) async =>
      EmployeeEntity(
        id: e.id,
        nom: e.nom,
        prenom: e.prenom,
        telephone: e.telephone,
        posteId: e.posteId,
        posteNom: postesParId[e.posteId],
        dateEmbauche: e.dateEmbauche,
        typeContrat: e.typeContrat,
        salaireBase: e.salaireBase,
        statut: e.statut,
        dateDepart: e.dateDepart,
        notes: e.notes,
        userId: e.userId,
        dateCreation: e.dateCreation,
      );

  Future<Map<int, String>> _postesParId() async {
    final postes = await db.personnelDao.getAllJobPositions();
    return {for (final p in postes) p.id: p.nom};
  }

  Future<List<EmployeeEntity>> _toEntities(List<Employee> list) async {
    final postes = await _postesParId();
    final result = <EmployeeEntity>[];
    for (final e in list) {
      result.add(await _toEntity(e, postes));
    }
    return result;
  }

  @override
  Future<List<JobPositionEntity>> getAllJobPositions() async {
    final rows = await db.personnelDao.getAllJobPositions();
    return rows
        .map((p) => JobPositionEntity(id: p.id, nom: p.nom, actif: p.actif))
        .toList();
  }

  @override
  Future<int> createJobPosition(String nom) => db.personnelDao
      .createJobPosition(JobPositionsCompanion.insert(nom: nom));

  @override
  Future<List<EmployeeEntity>> getAllEmployees() async {
    final rows = await db.personnelDao.getAllEmployees();
    return _toEntities(rows);
  }

  @override
  Future<List<EmployeeEntity>> getActiveEmployees() async {
    final rows = await db.personnelDao.getActiveEmployees();
    return _toEntities(rows);
  }

  @override
  Future<EmployeeEntity?> getEmployeeById(int id) async {
    final row = await db.personnelDao.getEmployeeById(id);
    if (row == null) return null;
    return _toEntity(row, await _postesParId());
  }

  @override
  Future<List<EmployeeEntity>> searchEmployees(String query) async {
    final rows = await db.personnelDao.searchEmployees(query);
    return _toEntities(rows);
  }

  @override
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
  }) {
    return db.personnelDao.createEmployee(EmployeesCompanion.insert(
      nom: nom,
      prenom: prenom,
      telephone: Value(telephone),
      posteId: posteId,
      dateEmbauche: dateEmbauche,
      typeContrat: Value(typeContrat),
      salaireBase: Value(salaireBase),
      notes: Value(notes),
      userId: Value(userId),
      createdById: Value(createdById),
    ));
  }

  @override
  Future<void> updateEmployee(EmployeeEntity employee) async {
    await db.personnelDao.updateEmployee(
      employee.id,
      EmployeesCompanion(
        nom: Value(employee.nom),
        prenom: Value(employee.prenom),
        telephone: Value(employee.telephone),
        posteId: Value(employee.posteId),
        dateEmbauche: Value(employee.dateEmbauche),
        typeContrat: Value(employee.typeContrat),
        salaireBase: Value(employee.salaireBase),
        statut: Value(employee.statut),
        dateDepart: Value(employee.dateDepart),
        notes: Value(employee.notes),
        userId: Value(employee.userId),
      ),
    );
  }

  @override
  Future<void> deactivateEmployee(int id, DateTime dateDepart) =>
      db.personnelDao.deactivateEmployee(id, dateDepart);

  @override
  Future<List<EmployeeAbsenceEntity>> getAbsencesForEmployee(
      int employeeId) async {
    final rows = await db.personnelDao.getAbsencesForEmployee(employeeId);
    return rows
        .map((a) => EmployeeAbsenceEntity(
              id: a.id,
              employeeId: a.employeeId,
              dateDebut: a.dateDebut,
              dateFin: a.dateFin,
              nombreJours: a.nombreJours,
              motif: a.motif,
              justifiee: a.justifiee,
              avecRetenue: a.avecRetenue,
              commentaire: a.commentaire,
              userId: a.userId,
              dateCreation: a.dateCreation,
            ))
        .toList();
  }

  @override
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
  }) {
    return db.personnelDao.createAbsence(EmployeeAbsencesCompanion.insert(
      employeeId: employeeId,
      dateDebut: dateDebut,
      dateFin: dateFin,
      nombreJours: nombreJours,
      motif: motif,
      justifiee: Value(justifiee),
      avecRetenue: Value(avecRetenue),
      commentaire: Value(commentaire),
      userId: userId,
    ));
  }

  @override
  Future<void> deleteAbsence(int id) => db.personnelDao.deleteAbsence(id);
}
