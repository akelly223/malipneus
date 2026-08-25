import 'package:drift/drift.dart';
import 'suppliers_table.dart';
import 'users_table.dart';

/// Un chargement (conteneur de pneus, ou tout lot d'approvisionnement).
///
/// Regroupe un ou plusieurs achats fournisseurs ([Purchases.chargementId])
/// et les dépenses annexes qui lui sont imputables ([Expenses.chargementId] :
/// transport, transitaire, douane, manutention...), pour calculer le prix
/// de revient réel et la rentabilité de ce lot (voir [StockLots]).
class Loadings extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Numéro affiché, ex: CHG-2026-0001.
  TextColumn get numero => text().withLength(min: 1, max: 30).unique()();

  /// Nom choisi par l'utilisateur (ex: "Chargement Awa"), distinct du
  /// [numero] auto-généré — fortement recommandé mais pas obligatoire
  /// pour ne pas bloquer les chargements existants sans nom.
  TextColumn get nom => text().nullable()();

  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id)();

  /// Date d'achat/expédition du chargement.
  DateTimeColumn get dateChargement => dateTime()();

  /// Date d'arrivée effective du chargement (dédouanement/réception),
  /// distincte de [dateChargement]. Nulle tant que le chargement n'est
  /// pas arrivé.
  DateTimeColumn get dateArrivee => dateTime().nullable()();

  /// Numéro de container, si applicable (transport maritime).
  TextColumn get container => text().nullable()();

  /// Référence libre du chargement (bon de commande fournisseur, numéro
  /// de dossier transitaire...), distincte du [numero] auto-généré.
  TextColumn get reference => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// 'ouvert' (dépenses encore attendues) | 'cloture' (coût final figé).
  TextColumn get statut => text().withDefault(const Constant('ouvert'))();

  IntColumn get createdById => integer().nullable().references(Users, #id)();
  TextColumn get createdByNom => text().nullable()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
