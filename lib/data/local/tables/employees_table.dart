import 'package:drift/drift.dart';
import 'job_positions_table.dart';
import 'users_table.dart';

/// Table du personnel (module Personnel).
///
/// [userId] est optionnel : un employé n'a pas forcément de compte de
/// connexion à l'application (ex: chauffeur, magasinier). Quand il est
/// renseigné, il relie l'employé à un compte [Users] existant.
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 100)();
  TextColumn get prenom => text().withLength(min: 1, max: 100)();
  TextColumn get telephone => text().nullable()();

  IntColumn get posteId => integer().references(JobPositions, #id)();

  DateTimeColumn get dateEmbauche => dateTime()();

  /// Ex: 'CDI', 'CDD', 'Journalier', 'Stage'. Libre, non contraint.
  TextColumn get typeContrat => text().nullable()();

  RealColumn get salaireBase => real().withDefault(const Constant(0))();

  /// 'actif' | 'inactif'
  TextColumn get statut => text().withDefault(const Constant('actif'))();

  DateTimeColumn get dateDepart => dateTime().nullable()();

  TextColumn get notes => text().nullable()();

  /// Compte de connexion optionnel lié à cet employé.
  IntColumn get userId => integer().nullable().references(Users, #id)();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  IntColumn get createdById => integer().nullable().references(Users, #id)();
}
