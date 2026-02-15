import 'package:drift/drift.dart';

class Downloads extends Table {
  TextColumn get id => text()();
  TextColumn get trackJson => text().named('track_json')();
  IntColumn get status => integer().withDefault(const Constant(0))(); // 0: pending, 1: downloading, 2: completed, 3: failed
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  TextColumn get filePath => text().nullable().named('file_path')();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get trackJson => text().named('track_json')();
  TextColumn get filePath => text().nullable().named('file_path')();
  IntColumn get playCount => integer().withDefault(const Constant(0)).named('play_count')();
  IntColumn get skipCount => integer().withDefault(const Constant(0)).named('skip_count')();
  RealColumn get score => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastPlayed => dateTime().nullable().named('last_played')();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

class Edges extends Table {
  TextColumn get sourceId => text().references(Songs, #id).named('source_id')();
  TextColumn get targetId => text().references(Songs, #id).named('target_id')(); // Can reference Songs
  RealColumn get weight => real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  @override
  Set<Column> get primaryKey => {sourceId, targetId};
}
