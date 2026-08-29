import 'package:drift/drift.dart';
import 'articles_table.dart';

/// Table des promotions commerciales — campagne de remise appliquée
/// automatiquement au prix de vente d'un ou plusieurs pneus pendant une
/// période donnée (voir [PromotionArticles] pour la sélection des pneus
/// couverts).
class Promotions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get nom => text().withLength(min: 1, max: 150)();

  /// 'pourcentage' ou 'montant' — voir [PromotionEntity.type].
  TextColumn get typeRemise =>
      text().withDefault(const Constant('pourcentage'))();

  /// Valeur de la remise : un pourcentage (0-100) si [typeRemise] vaut
  /// 'pourcentage', ou un montant en FCFA sinon.
  RealColumn get valeur => real()();

  DateTimeColumn get dateDebut => dateTime()();

  /// Fin de la période, incluse (normalisée à 23:59:59 le jour choisi
  /// par le formulaire pour couvrir toute la journée de fin).
  DateTimeColumn get dateFin => dateTime()();

  /// Interrupteur manuel indépendant des dates — permet de suspendre une
  /// promotion sans en modifier la période planifiée.
  BoolColumn get actif => boolean().withDefault(const Constant(true))();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Association many-to-many : pneus couverts par une promotion.
class PromotionArticles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// ON DELETE CASCADE : la suppression de la promotion supprime son
  /// association aux pneus.
  IntColumn get promotionId => integer()
      .customConstraint('NOT NULL REFERENCES promotions(id) ON DELETE CASCADE')();

  IntColumn get articleId => integer().references(Articles, #id)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {promotionId, articleId},
      ];
}
