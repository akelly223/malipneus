import 'package:drift/drift.dart';
import 'payslips_table.dart';
import 'users_table.dart';

/// Règlements d'un bulletin de paie. Calque de [DocumentPayments] : un
/// bulletin peut recevoir plusieurs règlements partiels. Aucune
/// suppression n'est jamais possible — historique immuable.
class PayslipPayments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get payslipId => integer().references(Payslips, #id)();

  RealColumn get montant => real()();
  DateTimeColumn get datePaiement => dateTime()();

  /// 'especes' | 'orange_money' | 'moov_money' | 'virement' | 'cheque'
  TextColumn get modePaiement =>
      text().withDefault(const Constant('especes'))();

  IntColumn get payeParUserId => integer().references(Users, #id)();
  TextColumn get payeParUserNom => text().nullable()();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}
