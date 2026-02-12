import 'dart:convert';
import 'dart:io';

class StockfishService {
  Process? _process;

  // 스톡피쉬 엔진 시작
  Future<void> startEngine() async {
    if (_process != null) return;

    // 윈도우 기준 경로 (배포 시 경로 처리 주의 필요)
    // 개발 환경에서는 프로젝트 루트 기준 상대 경로 사용 가능
    try {
      _process = await Process.start('lib/stockfish/stockfish.exe', []);
      _process!.stdin.writeln('uci');
      _process!.stdin.writeln('isready');
    } catch (e) {
      print("Stockfish Error: $e");
    }
  }

  // FEN을 받아 평가치(Eval)와 추천 수 타입 계산
  // depth: 분석 깊이 (실시간성을 위해 10~15 정도로 제한)
  Future<Map<String, dynamic>> analyze(String fen, {int depth = 10}) async {
    if (_process == null) await startEngine();

    _process!.stdin.writeln('position fen $fen');
    _process!.stdin.writeln('go depth $depth');

    double eval = 0.0;
    String type = 'book'; // 기본값

    // stdout 스트림을 단발성으로 듣기 위해 Completer 사용 가능하나,
    // 간단하게 broadcast stream을 리스닝하여 파싱 (여기선 약식 구현)

    // *실제 구현 시에는 스트림 리스너를 더 정교하게 짜야 합니다.*
    // 여기서는 개념적으로 "score cp" 값을 파싱한다고 가정합니다.
    await for (final event in _process!.stdout.transform(utf8.decoder)) {
      if (event.contains('score cp')) {
        // 예: info depth 10 ... score cp 50 ...
        final RegExp cpRegex = RegExp(r'score cp (-?\d+)');
        final match = cpRegex.firstMatch(event);
        if (match != null) {
          int cp = int.parse(match.group(1)!);
          eval = cp / 100.0; // centipawn to pawn unit
        }
      }
      if (event.contains('bestmove')) {
        // 분석 완료
        break;
      }
    }

    // 간단한 타입 판별 로직 (절대적 평가치 기준)
    if (eval > 1.0)
      type = 'best'; // 백 유리
    else if (eval < -1.0)
      type = 'mistake'; // 흑 유리 (관점에 따라 다름)
    else
      type = 'book'; // 균형

    return {'eval': eval, 'type': type};
  }

  void dispose() {
    _process?.kill();
  }
}
