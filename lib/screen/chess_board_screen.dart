// ./lib/screen/chess_board_screen.dart
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib; // 라이브러리 이름 충돌 방지
import 'package:audioplayers/audioplayers.dart';
import '../widgets/board_view.dart';
import '../widgets/info_view.dart';
import '../services/database_helper.dart';

class ChessBoardScreen extends StatefulWidget {
  const ChessBoardScreen({super.key});

  @override
  State<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends State<ChessBoardScreen> {
  // 1. 핵심 게임 상태 변수들
  late chess_lib.Chess _game; // 체스 엔진 인스턴스
  bool _isFlipped = false; // 보드 뒤집기 상태
  int _selectedIndex = -1; // 현재 선택된 칸 인덱스 (0~63)
  List<String> _validMoves = []; // 선택된 말의 이동 가능 칸 (e.g., ['e3', 'e4'])
  String _currentFen =
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq"; // 현재 포지션의 FEN 저장
  String _getNormalizedFen(String fen) {
    List<String> parts = fen.split(' ');
    // 0: 기물배치, 1: 턴, 2: 캐슬링권한, 3: 앙파상타겟
    // 뒤의 4, 5번(수치 데이터)은 오프닝 대조 시 방해가 될 수 있어 잘라냄
    return parts.sublist(0, 3).join(' ');
  }

  String _nameKo = "체스 시작";
  String _nameEn = "Starting Position";
  double _eval = 0.0;

  // Redo를 위한 히스토리 관리
  List<String> _fenHistory = [];
  int _historyPointer = 0;

  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _initAudio(); // 오디오 초기화 분리
    _resetGame();
  }

  void _initAudio() {
    _audioPlayer = AudioPlayer();
    // 1. 저지연 모드 설정 (SFX에 필수)
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    // 2. 윈도우에서 발생할 수 있는 이벤트 쓰레드 에러를 방지하기 위해
    // 이벤트 스트림을 구독하지 않거나 무시하도록 설정 (내부적으로 처리)
  }

  Future<void> _playSfx(String fileName) async {
    try {
      // 3. 소리가 겹칠 때 에러 방지를 위해 소스 먼저 지정 후 재생
      await _audioPlayer.play(
        AssetSource('sfx/$fileName.wav'),
        mode: PlayerMode.lowLatency, // 저지연 모드 명시
      );
    } catch (e) {
      debugPrint("Audio error: $e");
    }
  }

  Future<void> _updateOpeningInfo(String fen) async {
    final info = await DatabaseHelper().getOpeningByFen(fen);

    if (info != null) {
      setState(() {
        _nameKo = info['name_ko'] ?? "알 수 없는 오프닝";
        _nameEn = info['name_en'] ?? "Unknown Opening";
        _eval = (info['eval'] as num).toDouble();
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // 해제 필수
    super.dispose();
  }

  // 게임 초기화/리셋
  void _resetGame() {
    setState(() {
      _game = chess_lib.Chess(); // 새 게임 시작 (기본 FEN)
      _selectedIndex = -1;
      _validMoves = [];
      _fenHistory = [_game.fen]; // 초기 상태 저장
      _historyPointer = 0;
      // _isFlipped는 리셋 시 유지하거나 false로 초기화 선택 가능
      _currentFen = _getNormalizedFen(_game.fen); // 초기 FEN 저장
      _updateOpeningInfo(_currentFen);
    });
  }

  // --- 보드 터치 로직 (핵심) ---
  void _onSquareTapped(int index) {
    // 보드가 뒤집힌 상태면 인덱스를 반대로 계산
    final effectiveIndex = _isFlipped ? 63 - index : index;

    // 인덱스(0~63)를 좌표 표기법(a1~h8)으로 변환
    final rank = 8 - (effectiveIndex ~/ 8);
    final file = effectiveIndex % 8;
    final String squareName = '${String.fromCharCode(97 + file)}$rank';

    setState(() {
      // 1. 이미 선택된 말을 다시 누르면 선택 취소
      if (_selectedIndex == effectiveIndex) {
        _clearSelection();
        return;
      }

      // 2. 이동 가능한 칸을 눌렀다면 -> 이동 실행
      if (_validMoves.contains(squareName)) {
        _makeMove(squareName);
        return;
      }

      // 3. 내 턴의 기물을 눌렀다면 -> 선택 및 이동 가능 칸 표시
      final piece = _game.get(squareName);
      if (piece != null && piece.color == _game.turn) {
        _selectedIndex = effectiveIndex;

        // 'moves' 함수를 사용해야 하며, 'verbose: true'를 넣어야 Move 객체(정보 포함)를 받습니다.
        final moves = _game.moves({'square': squareName, 'verbose': true});

        // 받아온 Move 객체들에서 도착지(to) 좌표만 뽑아서 리스트로 만듭니다.
        // 해결책: Map에서 바로 'to' 키(Key)의 값을 꺼내옴
        _validMoves = moves.map((move) => move['to'] as String).toList();
      }
    });
  }

  void _clearSelection() {
    _selectedIndex = -1;
    _validMoves = [];
  }

  void _makeMove(String targetSquareName) {
    final rank = 8 - (_selectedIndex ~/ 8);
    final file = _selectedIndex % 8;
    final String fromSquareName = '${String.fromCharCode(97 + file)}$rank';

    // 1. move()는 이동 성공 시 true를 반환합니다.
    bool success = _game.move({
      'from': fromSquareName,
      'to': targetSquareName,
      'promotion': 'q',
    });

    if (success) {
      // 2. 방금 둔 수의 상세 정보는 history의 마지막 아이템에서 가져옵니다.
      final lastMove = _game.history.last.move;

      if (_game.in_checkmate) {
        _playSfx('gameover');
      } else if (_game.in_check) {
        _playSfx('check');
      } else {
        // 3. flags를 확인하여 사운드 결정
        // chess 라이브러리에서 flags는 비트마스크(int)인 경우가 많습니다.
        // BITS_CAPTURE = 2, BITS_EP_CAPTURE = 8, BITS_KSIDE_CASTLE = 32, BITS_QSIDE_CASTLE = 64
        final int f = lastMove.flags;

        bool isCapture = (f & 2 != 0) || (f & 8 != 0); // 일반 잡기 혹은 앙파상
        bool isCastling = (f & 32 != 0) || (f & 64 != 0); // 킹사이드 혹은 퀸사이드 캐슬링

        if (isCapture) {
          _playSfx('capture');
        } else if (isCastling) {
          _playSfx('castling');
        } else {
          _playSfx('move');
        }
      }

      // 히스토리 및 상태 관리 (동일)
      setState(() {
        _currentFen = _getNormalizedFen(_game.fen); // 이동 후 FEN 갱신
        if (_historyPointer < _fenHistory.length - 1) {
          _fenHistory = _fenHistory.sublist(0, _historyPointer + 1);
        }
        _fenHistory.add(_game.fen);
        _historyPointer++;
        _clearSelection();
      });

      _updateOpeningInfo(_currentFen);

      if (_game.in_checkmate) {
        debugPrint("Checkmate!");
      }
    }
  }

  // --- 컨트롤 버튼 기능 구현 ---
  void _undo() {
    if (_historyPointer > 0) {
      setState(() {
        _historyPointer--;
        _game.load(_fenHistory[_historyPointer]);
        _currentFen = _getNormalizedFen(_game.fen); // FEN 동기화
        _updateOpeningInfo(_currentFen);
        _clearSelection();
      });
    }
  }

  void _redo() {
    if (_historyPointer < _fenHistory.length - 1) {
      setState(() {
        _historyPointer++;
        _game.load(_fenHistory[_historyPointer]);
        _currentFen = _getNormalizedFen(_game.fen); // FEN 동기화
        _updateOpeningInfo(_currentFen);
        _clearSelection();
      });
    }
  }

  void _flipBoard() {
    setState(() {
      _isFlipped = !_isFlipped;
      _clearSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 상단 보드 뷰에 필요한 데이터를 모두 전달
          BoardView(
            game: _game,
            isFlipped: _isFlipped,
            selectedIndex: _selectedIndex,
            validMoves: _validMoves,
            onSquareTap: _onSquareTapped,
          ),
          // 하단 정보 뷰에 컨트롤 콜백 전달
          InfoView(
            nameKo: _nameKo,
            nameEn: _nameEn,
            evaluation: _eval,
            currentFen: _currentFen,
            onUndo: _undo,
            onRedo: _redo,
            onReset: _resetGame,
            onFlip: _flipBoard,
            canUndo: _historyPointer > 0,
            canRedo: _historyPointer < _fenHistory.length - 1,
          ),
        ],
      ),
    );
  }
}
