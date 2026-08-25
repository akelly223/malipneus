import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/loadings_table.dart';

part 'loadings_dao.g.dart';

@DriftAccessor(tables: [Loadings])
class LoadingsDao extends DatabaseAccessor<AppDatabase>
    with _$LoadingsDaoMixin {
  LoadingsDao(super.db);

  Future<List<Loading>> getAllLoadings() =>
      (select(loadings)..orderBy([(l) => OrderingTerm.desc(l.dateChargement)]))
          .get();

  Future<Loading?> getLoadingById(int id) =>
      (select(loadings)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<int> createLoading(LoadingsCompanion loading) =>
      into(loadings).insert(loading);

  Future<bool> updateLoading(Loading loading) =>
      update(loadings).replace(loading);
}
