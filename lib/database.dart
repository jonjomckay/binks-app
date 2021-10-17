import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_migration_plan/migration/sql.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

const DATABASE_FILENAME = 'binks.db';

const TABLE_MOOD = 'mood';
const TABLE_MOOD_TAG = 'mood_tag';
const TABLE_PHOTO = 'photo';
const TABLE_TAG = 'tag';

class Database {
  static sqflite.Database? _readOnly;
  static sqflite.Database? _writable;

  static Future<sqflite.Database> readOnly() async {
    if (_readOnly == null) {
      _readOnly = await openDatabase(DATABASE_FILENAME,
          readOnly: true, singleInstance: false);
    }

    return _readOnly!;
  }

  static Future<sqflite.Database> writable() async {
    if (_writable == null) {
      _writable = await openDatabase(DATABASE_FILENAME);
    }

    return _writable!;
  }

  static Future migrate() async {
    var migrationPlan = MigrationPlan({
      2: [
        SqlMigration('''
        CREATE TABLE IF NOT EXISTS $TABLE_MOOD (
          date DATE NOT NULL PRIMARY KEY,
          mood TINYINT,
          comment VARCHAR
        );
''', reverseSql: 'DROP TABLE $TABLE_MOOD')
      ],
      3: [
        SqlMigration('''
        CREATE TABLE IF NOT EXISTS $TABLE_TAG (
          id INTEGER NOT NULL PRIMARY KEY,
          tag VARCHAR NOT NULL UNIQUE
        )
        ''', reverseSql: 'DROP TABLE $TABLE_TAG; DROP TABLE $TABLE_MOOD_TAG'),

        SqlMigration('''
        INSERT INTO $TABLE_TAG (id, tag) VALUES
        (1, 'alcohol'), (2, 'anniversary'), (3, 'baking'), (4, 'beach'), (5, 'cleaning'), 
        (6, 'cooking'), (7, 'cycling'), (8, 'eating out'), (9, 'haircut'), (10, 'holiday'), 
        (11, 'ill'), (12, 'lockdown'), (13, 'party'), (14, 'reading'), (15, 'shopping');
        '''),

        SqlMigration('''
        CREATE TABLE IF NOT EXISTS $TABLE_MOOD_TAG (
          mood_date DATE NOT NULL,
          tag_id INTEGER NOT NULL,
          
          PRIMARY KEY (mood_date, tag_id),
          FOREIGN KEY (mood_date) REFERENCES $TABLE_MOOD (date) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES $TABLE_TAG (id) ON DELETE CASCADE
        )
        ''')
      ],
      5: [
        // TODO: Change blake3 to checksum
        SqlMigration('''
        CREATE TABLE IF NOT EXISTS $TABLE_PHOTO (
          id VARCHAR PRIMARY KEY,
          blake3 VARCHAR NOT NULL,
          created_at TIMESTAMP NOT NULL,
          touched_at TIMESTAMP NOT NULL
        )
        ''', reverseSql: 'DROP TABLE $TABLE_PHOTO')
      ]
    });

    var database = await openDatabase(
      DATABASE_FILENAME,
      onCreate: migrationPlan,
      onDowngrade: migrationPlan,
      onUpgrade: migrationPlan,
      version: 5,
    );

    log('Finished migrating database to version ${await database.getVersion()}');
  }
}
