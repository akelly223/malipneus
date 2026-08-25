import 'package:drift/drift.dart';
import 'employees_table.dart';
import 'users_table.dart';

/// Règlement de commissions commerciales pour un employé sur une
/// période librement choisie par le responsable. N'existe qu'une fois
/// le règlement effectué (comme [DocumentPayments]) : il n'y a pas de
/// ligne "à régler" stockée, c'est une requête live sur
/// `document_lines` dont `commission_settlement_id IS NULL`.
///
/// Une fois créé, ce règlement est référencé par
/// `document_lines.commission_settlement_id` sur toutes les lignes
/// qu'il couvre, ce qui empêche tout double paiement par construction
/// (traçabilité Vente → Commercial → Commission → Règlement).
class CommissionSettlements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  DateTimeColumn get periodeDebut => dateTime()();
  DateTimeColumn get periodeFin => dateTime()();

  IntColumn get nombreVentes => integer().withDefault(const Constant(0))();
  RealColumn get quantiteTotale => real().withDefault(const Constant(0))();
  RealColumn get montantVentesTotal => real().withDefault(const Constant(0))();
  RealColumn get montantCommission => real().withDefault(const Constant(0))();

  DateTimeColumn get datePaiement => dateTime()();

  /// 'especes' | 'orange_money' | 'moov_money' | 'virement' | 'cheque'
  TextColumn get modePaiement =>
      text().withDefault(const Constant('especes'))();

  IntColumn get payeParUserId => integer().references(Users, #id)();
  TextColumn get payeParUserNom => text().nullable()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get notes => text().nullable()();
}
