// ./lib/services/database_helper.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // 1. 기기 내 DB 저장 경로 확인
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, "chessDB.sqlite");

    try {
      await Directory(dirname(path)).create(recursive: true);
    } catch (_) {}

    // Assets에서 최신 데이터 읽기
    ByteData data = await rootBundle.load(join("assets", "chessDB.sqlite"));
    List<int> bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    // 기존 파일이 있더라도 무조건 덮어쓰기 (flush: true)
    await File(path).writeAsBytes(bytes, flush: true);

    // 3. DB 열기
    return await openDatabase(path, readOnly: true);
  }

  // FEN으로 오프닝 정보 가져오기
  Future<Map<String, dynamic>?> getOpeningByFen(String normalizedFen) async {
    final db = await database;

    // positions 테이블에서 4파트 FEN으로 조회
    // csv 구조에 맞춰 name_ko, name_en, eval을 가져옵니다.
    List<Map<String, dynamic>> maps = await db.query(
      'positions',
      columns: ['name_ko', 'name_en', 'eval'],
      where: 'fen = ?',
      whereArgs: [normalizedFen],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
}
