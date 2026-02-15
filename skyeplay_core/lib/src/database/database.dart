import 'package:drift/drift.dart';
import 'package:skyeplay_core/src/database/schema.dart';

export 'package:skyeplay_core/src/database/schema.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Downloads, Songs, Edges])
class SkyeplayDatabase extends _$SkyeplayDatabase {
  SkyeplayDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}
