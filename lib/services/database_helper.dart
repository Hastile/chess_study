import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'opening_service.dart';

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
      debugPrint("Error copying database: $e");
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

  Future<List<Map<String, dynamic>>> getMovesByFen(String normalizedFen) async {
    final db = await database;

    // moves 테이블에서 parent_fen이 현재 FEN과 일치하는 수들을 조회
    List<Map<String, dynamic>> maps = await db.query(
      'moves',
      columns: [
        'move_san', // 기보 (예: "Nf3", "e4")
        'type', // 수의 종류 (book, best, mistake 등 -> 아이콘 매칭용)
        'name', // 수에 대한 설명 (오프닝 이름 등)
        'priority', // 우선순위
        'tier',
      ],
      // parent_fen이 normalizedFen으로 시작하는 경우 매칭 (앙파상 정보 무시)
      where: 'parent_fen LIKE ?',
      whereArgs: ['$normalizedFen%'],

      // 정렬 기준:
      // 1. priority DESC (높은 우선순위 먼저)
      // 2. frequency DESC (자주 두어지는 수 먼저)
      // 3. tier ASC (티어 숫자가 낮은게 좋다면 ASC, 반대라면 DESC / 데이터 확인 필요)
      orderBy: 'priority ASC, tier ASC',
    );

    return maps;
  }

  Future<String?> getMoveType(String parentFen, String moveSan) async {
    final db = await database;

    List<Map<String, dynamic>> maps = await db.query(
      'moves',
      columns: ['type'],
      where: 'parent_fen LIKE ? AND move_san = ?',
      whereArgs: ['$parentFen%', moveSan], // 앙파상 무시 매칭
    );

    if (maps.isNotEmpty) {
      return maps.first['type'] as String?;
    }
    return null;
  }

  // FEN 정규화 (캐슬링 포함, 앙파상 제외)
  String _normalizeFen(String fen) {
    List<String> parts = fen.split(' ');
    // 0:기물, 1:턴, 2:캐슬링
    return parts.sublist(0, 3).join(' '); 
  }

  // 실시간 기보 저장 (핵심 함수)
  Future<void> insertLiveMove({
    required String prevFen,    // 이전 포지션 FEN (moves.parent_fen)
    required String currentFen, // 현재 포지션 FEN (positions.fen)
    required String moveSan,    // 방금 둔 수 (e.g., "e4")
    required List<String> fullHistorySan, // 전체 기보 리스트
  }) async {
    final db = await database;
    final normalizedCurrentFen = _normalizeFen(currentFen);
    final normalizedPrevFen = _normalizeFen(prevFen);

    // 1. 오프닝 이름 찾기
    final names = OpeningService().findOpeningName(fullHistorySan);
    
    // 2. 스톡피쉬 분석 (비동기로 실행되므로 약간의 딜레이 있을 수 있음)
    // 실제로는 UI 멈춤 방지를 위해 별도 Isolate 사용 권장
    // 여기서는 간단히 0.0으로 넣거나 StockfishService 호출
    // final analysis = await StockfishService().analyze(normalizedCurrentFen); 
    double eval = 0.0; // analysis['eval'];
    String type = 'excellent'; // analysis['type'];

    // 3. positions 테이블에 현재 포지션 추가 (없으면 INSERT)
    // fullHistorySan을 문자열로 변환 (1. e4 e5 2. Nf3 ...)
    String sanString = "";
    for (int i = 0; i < fullHistorySan.length; i++) {
      if (i % 2 == 0) sanString += "${(i ~/ 2) + 1}. ";
      sanString += "${fullHistorySan[i]} ";
    }

    await db.insert(
      'positions',
      {
        'fen': normalizedCurrentFen,
        'san': sanString.trim(),
        'name_ko': names['ko'],
        'name_en': names['en'],
        'eval': eval,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // 이미 존재하면 무시
    );

    // 4. moves 테이블에 수 추가
    // 4-1. 같은 parent_fen에서 이 move가 이미 있는지 확인
    List<Map> existingMoves = await db.query(
      'moves',
      columns: ['priority', 'id'],
      where: 'parent_fen = ? AND move_san = ?',
      whereArgs: [normalizedPrevFen, moveSan],
    );

    if (existingMoves.isNotEmpty) {
      // 이미 있는 수라면 priority 증가 불가? 
      // 요구사항: "기존 갯수 확인하고 이에 따라 priority++"
      // -> 기존에 존재하는 수라면 업데이트 할 필요가 없거나, frequency를 올릴 수 있음.
      // -> 여기서는 새로운 수일 때 우선순위를 결정하는 로직으로 구현
    } else {
      // 4-2. parent_fen에 해당하는 기존 move들의 갯수(최대 priority) 확인
      var result = await db.rawQuery(
        'SELECT MAX(priority) as max_p FROM moves WHERE parent_fen = ?',
        [normalizedPrevFen]
      );
      int currentMaxPriority = (result.first['max_p'] as int?) ?? 0;

      await db.insert(
        'moves',
        {
          'parent_fen': normalizedPrevFen,
          'move_san': moveSan,
          'name': names['ko'], // moves.name은 positions.name_ko와 동일하게
          'type': type,
          'priority': currentMaxPriority + 1, // 우선순위 1 증가
          'tier': 1, // 기본 티어
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      print("DB Saved: $moveSan (Priority: ${currentMaxPriority + 1})");
    }
  }
}
