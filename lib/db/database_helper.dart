import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../dto/people.dart';

class DatabaseHelper {
  static const dbVersion = 1;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'ai_camera${dbVersion}.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE people (
        id TEXT PRIMARY KEY,
        studentId TEXT,
        name TEXT NOT NULL,
        email TEXT,
        classification TEXT,
        embeddings TEXT
      )
    ''');
  }

  // Insert a People. If a record with same id exists, it will be replaced.
  Future<int> insertPeople(People people) async {
    final db = await database;
    return await db.insert(
      'people',
      people.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get a People by id
  Future<People?> getPeopleById(String id) async {
    final db = await database;
    final maps = await db.query(
      'people',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return People.fromMap(maps.first);
    }
    return null;
  }

  // Get all People
  Future<List<People>> getAllPeople() async {
    final db = await database;
    final maps = await db.query('people');
    return maps.map((m) => People.fromMap(m)).toList();
  }

  // Update an existing People
  Future<int> updatePeople(People people) async {
    final db = await database;
    return await db.update(
      'people',
      people.toMap(),
      where: 'id = ?',
      whereArgs: [people.id],
    );
  }

  // Delete a People
  Future<int> deletePeople(String id) async {
    final db = await database;
    return await db.delete(
      'people',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clear all people
  Future<int> clearAllPeople() async {
    final db = await database;
    return await db.delete('people');
  }

  // Close DB
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

