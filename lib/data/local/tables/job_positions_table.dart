import 'package:drift/drift.dart';

/// Table des postes du personnel (Magasinier, Responsable, Chauffeur,
/// Comptable, Commercial, Autre...). Configurable : le responsable peut
/// ajouter ses propres postes depuis l'écran Personnel.
class JobPositions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 100).unique()();

  BoolColumn get actif => boolean().withDefault(const Constant(true))();
}
