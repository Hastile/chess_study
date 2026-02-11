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

    // 폴더가 없으면 생성
    try {
      await Directory(dirname(path)).create(recursive: true);
    } catch (_) {}

    // 2. DB 파일이 존재하지 않을 때만 Assets에서 복사 (최적화)
    var file = File(path);
    try {
      // [수정] join 함수 대신 슬래시(/)를 사용한 문자열 직접 입력
      ByteData data = await rootBundle.load("assets/chessDB.sqlite");

      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );  

      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      print("Error copying database: $e");
      rethrow; // 에러 발생 시 상위로 전파
    }

    // 3. DB 열기
    return await openDatabase(path, readOnly: true);
  }

  // FEN으로 오프닝 정보 가져오기
  Future<Map<String, dynamic>?> getOpeningByFen(String normalizedFen) async {
    final db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'positions',
      columns: ['name_ko', 'name_en', 'eval'],
      where: 'fen LIKE ?',
      whereArgs: ['$normalizedFen%'],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
}
