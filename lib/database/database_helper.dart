import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'batje_a_bo.db');

    final fileExists = await File(path).exists();
    if (!fileExists) {
      // Copier depuis les assets (assure-toi d'ajouter le fichier dans pubspec.yaml)
      final data = await rootBundle.load('assets/database/batje_a_bo.db');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(path);
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
