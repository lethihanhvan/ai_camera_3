import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../dto/people.dart';

class DatabaseHelper {
  // bump database version to add `images` column
  static const dbVersion = 2;
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
    // use a stable filename (do not include version in filename) so onUpgrade runs
    final path = join(databasesPath, 'ai_camera.db');

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
        embeddings TEXT,
        images TEXT
      )
    ''');
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Add new columns or perform migrations here.
    // We only need to add the `images` column when upgrading from v1 -> v2.
    if (oldVersion < 2) {
      // Check if column already exists is optional; SQLite will throw if it already exists.
      await db.execute('ALTER TABLE people ADD COLUMN images TEXT');
    }
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

    // Clean up images and embeddings list - remove duplicates
    final uniqueEmbeddings = <List<double>>[];
    final seenEmbeddings = <String>{};

    for (final embedding in people.embeddings) {
      // Create a string representation of the embedding for comparison
      final embeddingKey = embedding.join(',');
      if (!seenEmbeddings.contains(embeddingKey)) {
        seenEmbeddings.add(embeddingKey);
        uniqueEmbeddings.add(embedding);
      }
    }

    final uniqueImages = <Uint8List>[];
    final seenImages = <String>{};

    for (final image in people.images) {
      // Use base64 encoding for comparison to avoid memory issues with large byte arrays
      final imageKey = base64Encode(image);
      if (!seenImages.contains(imageKey)) {
        seenImages.add(imageKey);
        uniqueImages.add(image);
      }
    }

    // Create cleaned People object
    final cleanedPeople = People(
      id: people.id,
      name: people.name,
      studentId: people.studentId,
      email: people.email,
      classification: people.classification,
      embeddings: uniqueEmbeddings,
      images: uniqueImages,
    );

    return await db.update(
      'people',
      cleanedPeople.toMap(),
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
