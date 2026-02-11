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

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.brown, width: 2),
              boxShadow: [
                const BoxShadow(blurRadius: 10, color: Colors.black26),
              ],
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemCount: 64,
              itemBuilder: (context, index) {
                // 플립 상태에 따라 실제 보드 인덱스 계산
                final effectiveIndex = isFlipped ? 63 - index : index;
                final rank = 8 - (effectiveIndex ~/ 8);
                final file = effectiveIndex % 8;
                final squareName = '${String.fromCharCode(97 + file)}$rank';

                // 배경색 계산
                bool isLight = (rank + file) % 2 != 0;
                Color bgColor = isLight
                    ? const Color(0xFFEBECD0)
                    : const Color(0xFF739552);

                // 하이라이트 로직
                if (effectiveIndex == selectedIndex) {
                  bgColor = const Color(0xFFB9CA43);
                }

                // 해당 칸의 기물 정보 가져오기
                final piece = game.get(squareName);
                final assetPath = _getPieceAsset(piece);

                return GestureDetector(
                  onTap: () => onSquareTap(index), // 부모에게 탭 이벤트 전달
                  child: Container(
                    color: bgColor,
                    child: assetPath != null
                        ? Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.asset(assetPath),
                          )
                        : (validMoves.contains(squareName)
                              ? Center(
                                  // 빈 칸인데 이동 가능하면 점 표시
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
