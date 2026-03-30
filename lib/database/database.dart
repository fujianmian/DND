import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// This line is required for code generation
part 'database.g.dart';

// 1. Define the Table
class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get type => integer()(); // 0 for Time, 1 for Location

  // Time params
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();

  // Location params
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
}

// 2. The Database Class
@DriftDatabase(tables: [Rules])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Simple Queries for MVP
  // 1. CREATE: Insert a new rule
  Future<int> insertRule(RulesCompanion rule) => into(rules).insert(rule);

  // 2. READ: Watch rules (returns a Stream for reactive UI updates)
  Stream<List<Rule>> watchAllRules() => select(rules).watch();

  // 3. UPDATE: Toggle enable/disable or edit rule
  Future<bool> updateRule(Rule rule) => update(rules).replace(rule);

  // 4. DELETE: Remove a rule
  Future<int> deleteRule(Rule rule) => delete(rules).delete(rule);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
