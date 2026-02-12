// ./lib/screen/chess_board_screen.dart
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:audioplayers/audioplayers.dart';
import '../widgets/board_view.dart';
import '../widgets/info_view.dart';
import '../services/database_helper.dart';
import '../services/opening_service.dart';

class ChessBoardScreen extends StatefulWidget {
  const ChessBoardScreen({super.key});

  @override
  State<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends State<ChessBoardScreen> {
  late chess_lib.Chess _game;
  bool _isFlipped = false;
  int _selectedIndex = -1;
  List<String> _validMoves = [];
  String _currentFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq";

  // [추가] 추천 수 및 아이콘 상태 변수
  List<Map<String, dynamic>> _recommendedMoves = [];
  String? _lastMoveType;

  String _nameKo = "체스 시작";
  String _nameEn = "Starting Position";
  double _eval = 0.0;

  List<String> _fenHistory = [];
  List<String?> _moveTypeHistory = [];
  List<chess_lib.Move?> _moveObjectHistory = [];
  chess_lib.Move? _lastMove;
  int _historyPointer = 0;

  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _resetGame();
    OpeningService().loadOpenings();
  }

  void _initAudio() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _playSfx(String fileName) async {
    try {
      await _audioPlayer.play(
        AssetSource('sfx/$fileName.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint("Audio error: $e");
    }
  }

  Future<void> _updateOpeningInfo(String fen) async {
    final info = await DatabaseHelper().getOpeningByFen(fen);
    final moves = await DatabaseHelper().getMovesByFen(fen);

    if (mounted) {
      setState(() {
        if (info != null) {
          _nameKo = info['name_ko'] ?? "알 수 없는 오프닝";
          _nameEn = info['name_en'] ?? "Unknown Opening";
          _eval = (info['eval'] as num).toDouble();
        } else {
          // DB에 없는 경우 초기화
          _nameKo = "알 수 없는 오프닝";
          _nameEn = "";
          _eval = 0.0;
        }
        _recommendedMoves = moves;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _game = chess_lib.Chess();
      _selectedIndex = -1;
      _validMoves = [];
      _fenHistory = [_game.fen];
      _moveTypeHistory = [null];
      _moveObjectHistory = [null];
      _historyPointer = 0;
      _currentFen = _getNormalizedFen(_game.fen);
      _lastMove = null;
      _lastMoveType = null;
      _recommendedMoves = [];
    });
    _updateOpeningInfo(_currentFen);
  }

  String _getNormalizedFen(String fen) {
    List<String> parts = fen.split(' ');
    return parts.sublist(0, 3).join(' ');
  }

  void _onSquareTapped(int index) {
    final effectiveIndex = _isFlipped ? 63 - index : index;
    final rank = 8 - (effectiveIndex ~/ 8);
    final file = effectiveIndex % 8;
    final String squareName = '${String.fromCharCode(97 + file)}$rank';

    setState(() {
      if (_selectedIndex == effectiveIndex) {
        _clearSelection();
        return;
      }

      if (_validMoves.contains(squareName)) {
        _makeMove(squareName);
        return;
      }

      final piece = _game.get(squareName);
      if (piece != null && piece.color == _game.turn) {
        _selectedIndex = effectiveIndex;
        final moves = _game.moves({'square': squareName, 'verbose': true});
        _validMoves = moves.map((move) => move['to'] as String).toList();
      }
    });
  }

  void _clearSelection() {
    _selectedIndex = -1;
    _validMoves = [];
  }

  // [핵심 수정] async 적용 및 SAN 문자열 추출 방식 변경
  Future<void> _makeMove(String targetSquareName) async {
    // 이동 전 FEN 저장 (DB 조회용)
    final String prevFen = _game.fen;

    final rank = 8 - (_selectedIndex ~/ 8);
    final file = _selectedIndex % 8;
    final String fromSquareName = '${String.fromCharCode(97 + file)}$rank';

    // 1. 실제 기물 이동 시도 (성공 시 true 반환)
    bool success = _game.move({
      'from': fromSquareName,
      'to': targetSquareName,
      'promotion': 'q',
    });

    if (success) {
      // [수정 1] State 객체에서 Move 객체 꺼내기
      // _game.history.last는 State이고, State.move가 실제 Move 객체입니다.
      final lastMove = _game.history.last.move;

      // 2. 사운드 재생 로직 (Move 객체의 flags 사용)
      if (_game.in_checkmate) {
        _playSfx('gameover');
      } else if (_game.in_check) {
        _playSfx('check');
      } else {
        final int f = lastMove.flags;
        // 비트 연산자로 플래그 확인 (CAPTURES, CASTLING 등)
        bool isCapture =
            (f & 2 != 0) || (f & 8 != 0); // BITS_CAPTURE, BITS_EP_CAPTURE
        bool isCastling = (f & 32 != 0) || (f & 64 != 0); // K_CASTLE, Q_CASTLE

        if (isCapture) {
          _playSfx('capture');
        } else if (isCastling) {
          _playSfx('castling');
        } else {
          _playSfx('move');
        }
      }

      // [수정 2] SAN(기보) 문자열은 별도 함수로 가져와야 함
      // Move 객체에는 san 속성이 없으므로, san_moves() 리스트의 마지막 항목 사용
      final String currentFen = _game.fen;

      String? lastMoveSan;
      try {
        lastMoveSan = _game.san_moves().last?.split(' ').last;
      } catch (e) {
        lastMoveSan = null;
      }

      List<String> fullHistory = _game
          .san_moves()
          .map((s) => s.split(' ').last)
          .toList();

      // 3. DB에서 추천 수 타입 조회 (아이콘 표시용)
      String? type;
      if (lastMoveSan != null) {
        await DatabaseHelper().insertLiveMove(
          prevFen: prevFen,
          currentFen: currentFen,
          moveSan: lastMoveSan,
          fullHistorySan: fullHistory,
        );
        type = await DatabaseHelper().getMoveType(prevFen, lastMoveSan);
      }

      setState(() {
        _lastMove = lastMove;
        _lastMoveType = type; // 아이콘 타입 업데이트
        _currentFen = _getNormalizedFen(_game.fen);

        // 히스토리 관리
        if (_historyPointer < _fenHistory.length - 1) {
          _fenHistory = _fenHistory.sublist(0, _historyPointer + 1);
          _moveTypeHistory = _moveTypeHistory.sublist(0, _historyPointer + 1);
        }
        _fenHistory.add(_game.fen);
        _moveTypeHistory.add(type);
        _moveObjectHistory.add(lastMove);
        _historyPointer++;
        _clearSelection();
      });

      // 오프닝 정보 및 추천 수 리스트 갱신
      _updateOpeningInfo(_currentFen);
    }
  }

  void _undo() {
    if (_historyPointer > 0) {
      setState(() {
        _historyPointer--;
        _game.load(_fenHistory[_historyPointer]);
        _currentFen = _getNormalizedFen(_game.fen);
        _lastMove = _moveObjectHistory[_historyPointer];
        _lastMoveType = _moveTypeHistory[_historyPointer];
        _clearSelection();
      });
      _updateOpeningInfo(_currentFen);
    }
  }

  void _redo() {
    if (_historyPointer < _fenHistory.length - 1) {
      setState(() {
        _historyPointer++;
        _game.load(_fenHistory[_historyPointer]);
        _currentFen = _getNormalizedFen(_game.fen);
        _lastMove = _moveObjectHistory[_historyPointer];
        _lastMoveType = _moveTypeHistory[_historyPointer];
        _clearSelection();
      });
      _updateOpeningInfo(_currentFen);
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
      backgroundColor: const Color(0xFF161512),
      body: Column(
        children: [
          BoardView(
            game: _game,
            isFlipped: _isFlipped,
            selectedIndex: _selectedIndex,
            validMoves: _validMoves,
            onSquareTap: _onSquareTapped,
            lastMove: _lastMove,
            lastMoveType: _lastMoveType,
          ),
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
            recommendedMoves: _recommendedMoves,
          ),
        ],
      ),
    );
  }
}
