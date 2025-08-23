import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'playlist.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE playlist(
            id TEXT PRIMARY KEY,
            title TEXT,
            audioPath TEXT,
            coverPath TEXT,
            subtitles TEXT
          )
        ''');
      },
    );
  }

  static Future<int> upsertSong(Map<String, dynamic> song) async {
    final d = await db;
    return d.insert('playlist', song, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getSongs() async {
    final d = await db;
    return d.query('playlist', orderBy: 'title COLLATE NOCASE');
  }

  static Future<Map<String, dynamic>?> getSong(String id) async {
    final d = await db;
    final res = await d.query('playlist', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isEmpty) return null;
    return res.first;
  }

  static Future<int> deleteSong(String id) async {
    final d = await db;
    return d.delete('playlist', where: 'id = ?', whereArgs: [id]);
  }
}
