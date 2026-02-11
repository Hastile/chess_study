// ./lib/widgets/board_view.dart
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;

class BoardView extends StatelessWidget {
  final chess_lib.Chess game;
  final bool isFlipped;
  final int selectedIndex;
  final List<String> validMoves;
  final Function(int) onSquareTap;

  const BoardView({
    super.key,
    required this.game,
    required this.isFlipped,
    required this.selectedIndex,
    required this.validMoves,
    required this.onSquareTap,
  });

  // 라이브러리의 기물 정보를 유저의 어셋 파일명으로 변환하는 헬퍼 함수
  String? _getPieceAsset(chess_lib.Piece? piece) {
    if (piece == null) return null;
    String color = piece.color == chess_lib.Color.WHITE ? 'White' : 'Black';
    String type = switch (piece.type) {
      chess_lib.PieceType.PAWN => 'Pawn',
      chess_lib.PieceType.KNIGHT => 'Knight',
      chess_lib.PieceType.BISHOP => 'Bishop',
      chess_lib.PieceType.ROOK => 'Rook',
      chess_lib.PieceType.QUEEN => 'Queen',
      chess_lib.PieceType.KING => 'King',
      _ => '',
    };
    // 사용자가 지정한 경로와 확장자(.webp)
    return 'assets/images/Units/$color$type.webp';
  }

  // 좌표 문자열(e.g., "e4")을 인덱스(0~63)로 변환
  int _squareToIndex(String square) {
    int file = square.codeUnitAt(0) - 97; // 'a' -> 0
    int rank = int.parse(square[1]) - 1; // '1' -> 0
    return (7 - rank) * 8 + file;
  }

  @override
  Widget build(BuildContext context) {
    // 마지막 이동 정보 (하이라이트용)
    final lastMove = game.history.isNotEmpty ? game.history.last.move : null;
    int? lastFromIndex;
    int? lastToIndex;

    if (lastMove != null) {
      lastFromIndex = _squareToIndex(lastMove.fromAlgebraic);
      lastToIndex = _squareToIndex(lastMove.toAlgebraic);
    }

    // 체크 상태인 킹 위치 찾기
    int? checkKingIndex;
    if (game.in_check) {
      for (int i = 0; i < 64; i++) {
        final rank = 8 - (i ~/ 8);
        final file = i % 8;
        final squareName = '${String.fromCharCode(97 + file)}$rank';
        final piece = game.get(squareName);

        if (piece != null &&
            piece.type == chess_lib.PieceType.KING &&
            piece.color == game.turn) {
          checkKingIndex = i;
          break;
        }
      }
    }
    return Expanded(
      flex: 1,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF403A34), width: 4),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 15,
                  color: Colors.black45,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 한 칸의 크기 계산
                final squareSize = constraints.maxWidth / 8;

                return Stack(
                  children: [
                    // [Layer 1] 배경 보드 (색상 및 탭 이벤트)
                    _buildBoardSquares(
                      squareSize,
                      lastFromIndex,
                      lastToIndex,
                      checkKingIndex,
                    ),

                    // [Layer 2] 기물 (AnimatedPositioned 적용)
                    ..._buildPieces(squareSize),

                    // [Layer 3] 힌트 (이동 가능 표시, 캡처 링)
                    ..._buildMoveHints(squareSize),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // 배경 격자 생성
  Widget _buildBoardSquares(
    double squareSize,
    int? lastFrom,
    int? lastTo,
    int? checkKing,
  ) {
    return Column(
      children: List.generate(8, (rankIndex) {
        return Row(
          children: List.generate(8, (fileIndex) {
            final int rawIndex = rankIndex * 8 + fileIndex;
            final int displayIndex = isFlipped ? 63 - rawIndex : rawIndex;

            final int effectiveRank = displayIndex ~/ 8;
            final int effectiveFile = displayIndex % 8;

            // [수정 완료] 합이 짝수일 때 밝은 색
            final bool isLight = (effectiveRank + effectiveFile) % 2 == 0;

            Color squareColor = isLight
                ? const Color(0xFFEBECD0)
                : const Color(0xFF739552);

            // 하이라이트 우선순위: 체크 > 선택 > 마지막 이동
            if (displayIndex == checkKing) {
              squareColor = const Color(0xFFE55C5C).withOpacity(0.9); // 체크
            } else if (displayIndex == selectedIndex) {
              squareColor = const Color(0xFFBBCB43); // 선택됨
            } else if (displayIndex == lastFrom || displayIndex == lastTo) {
              squareColor = const Color(0xFFF5F682).withOpacity(0.8); // 마지막 이동
            }

            return GestureDetector(
              onTap: () => onSquareTap(displayIndex),
              child: Container(
                width: squareSize,
                height: squareSize,
                color: squareColor,
              ),
            );
          }),
        );
      }),
    );
  }

  // 기물 렌더링 (애니메이션 핵심)
  List<Widget> _buildPieces(double squareSize) {
    List<Widget> pieces = [];

    // 0(a8) ~ 63(h1) 보드 전체를 순회
    for (int i = 0; i < 64; i++) {
      // 인덱스 -> 좌표 문자열 (e.g., "e4")
      final rank = 8 - (i ~/ 8);
      final file = i % 8;
      final squareName = '${String.fromCharCode(97 + file)}$rank';

      // 안전하게 기물 정보 가져오기
      final piece = game.get(squareName);
      if (piece == null) continue;

      final assetPath = _getPieceAsset(piece);
      if (assetPath == null) continue;

      // 화면에 표시될 좌표(row, col) 계산
      int row = i ~/ 8;
      int col = i % 8;

      // 보드 뒤집기 상태 반영
      if (isFlipped) {
        row = 7 - row;
        col = 7 - col;
      }

      pieces.add(
        AnimatedPositioned(
          // Key가 중요합니다. 여기서는 위치 기반으로 유니크 키를 생성합니다.
          // 참고: 완벽한 슬라이딩을 위해서는 기물 고유 ID 추적이 필요하지만,
          // 이 방식으로도 훨씬 부드러운 위치 이동 효과를 볼 수 있습니다.
          key: ValueKey(
            'piece_${squareName}_${piece.type.name}_${piece.color.name}',
          ),
          duration: const Duration(milliseconds: 200), // 애니메이션 속도
          curve: Curves.easeOutQuad, // 부드러운 감속 커브
          left: col * squareSize,
          top: row * squareSize,
          width: squareSize,
          height: squareSize,
          child: IgnorePointer(
            // 기물 이미지가 터치를 가로채지 않도록 설정
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Image.asset(assetPath),
            ),
          ),
        ),
      );
    }
    return pieces;
  }

  // 힌트(점, 링) 렌더링
  List<Widget> _buildMoveHints(double squareSize) {
    List<Widget> hints = [];

    for (String moveSquare in validMoves) {
      int index = _squareToIndex(moveSquare);
      int row = index ~/ 8;
      int col = index % 8;

      if (isFlipped) {
        row = 7 - row;
        col = 7 - col;
      }

      final targetPiece = game.get(moveSquare);
      bool isCapture = targetPiece != null;

      hints.add(
        Positioned(
          left: col * squareSize,
          top: row * squareSize,
          width: squareSize,
          height: squareSize,
          child: IgnorePointer(
            child: Center(
              child: isCapture
                  ? // 상대 기물이 있는 경우: 큰 링
                    Container(
                      width: squareSize,
                      height: squareSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withOpacity(0.15),
                          width: squareSize * 0.1,
                        ),
                      ),
                    )
                  : // 빈 칸인 경우: 작은 점
                    Container(
                      width: squareSize * 0.35,
                      height: squareSize * 0.35,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ),
      );
    }
    return hints;
  }
}
