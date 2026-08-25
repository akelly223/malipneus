import 'package:drift/drift.dart';

/// Paramètres de paie de l'entreprise. Conçue pour ne contenir qu'une
/// seule ligne (id fixe = 1), même pattern que [AppSettings].
///
/// La règle de retenue d'absence n'est PAS supposée par l'application :
/// c'est le responsable qui configure le nombre de jours théoriques par
/// mois utilisé pour calculer la retenue journalière
/// (retenue = salaire_base / jours_theoriques_par_mois × jours_absence).
class PayrollSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  RealColumn get joursTheoriquesParMois =>
      real().withDefault(const Constant(30))();

  DateTimeColumn get dateModification => dateTime().nullable()();
}
