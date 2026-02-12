// ./lib/widgets/info_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InfoView extends StatelessWidget {
  // 컨트롤 버튼을 위한 콜백 함수들
  final String nameKo; // 추가
  final String nameEn; // 추가
  final double evaluation; // 추가
  final String currentFen;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;
  final VoidCallback onFlip;
  final bool canUndo;
  final bool canRedo;

  final List<Map<String, dynamic>> recommendedMoves;

  const InfoView({
    super.key,
    required this.nameKo,
    required this.nameEn,
    required this.evaluation,
    required this.currentFen,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onFlip,
    required this.canUndo,
    required this.canRedo,
    this.recommendedMoves = const [], // 기본값 빈 리스트
  });

  Color _getMoveColor(String type) {
    return switch (type.toLowerCase()) {
      'brilliant' || 'critical' => const Color(0xFF1AADA7), // 청록색
      'best' || 'excellent' => const Color(0xFF91B045), // 연두색
      'book' => const Color(0xFFA98865), // 갈색
      'okay' => const Color(0xFF9AA3AF), // 회색
      'inaccuracy' => const Color(0xFFF7C044), // 노란색
      'mistake' => const Color(0xFFE58F2A), // 주황색
      'blunder' => const Color(0xFFCA3430), // 빨간색
      'forced' => const Color(0xFF4A4A4A), // 진한 회색
      _ => const Color(0xFF64748B), // 기본 (Unknown)
    };
  }

  String _getMoveLabel(String type) {
    // 첫 글자 대문자로 변환
    if (type.isEmpty) return "Unknown";
    return type[0].toUpperCase() + type.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 새로 추가된 컨트롤 버튼 영역 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  Icons.undo,
                  'Undo',
                  onUndo,
                  enabled: canUndo,
                ),
                _buildControlButton(
                  Icons.redo,
                  'Redo',
                  onRedo,
                  enabled: canRedo,
                ),
                _buildControlButton(Icons.restart_alt, 'Reset', onReset),
                _buildControlButton(Icons.flip_camera_android, 'Flip', onFlip),
              ],
            ),
            const SizedBox(height: 16),

            // 평가치 바 (기존 동일)
            const SizedBox(height: 8),
            _buildEvalBar(evaluation),
            const SizedBox(height: 24),

            // (나머지 오프닝 정보 및 히스토리 UI는 이전과 동일하게 유지...)
            Text(
              nameKo,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(nameEn, style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),

            Expanded(
              child: recommendedMoves.isEmpty
                  ? const Center(
                      child: Text(
                        "추천 수가 없습니다.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: recommendedMoves.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = recommendedMoves[index];
                        final String moveSan = item['move_san'] ?? '';
                        final String type = item['type'] ?? 'unknown';
                        final String name = item['name'] ?? '';
                        final Color color = _getMoveColor(type);

                        return _buildRecommendationItem(
                          moveSan,
                          type,
                          name,
                          color,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
    String moveSan,
    String type,
    String name,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10), // 반투명 배경
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // 왼쪽 인디케이터 바
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),

                // 텍스트 정보 (기보 + 설명)
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        moveSan,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE7EDF5),
                        ),
                      ),
                      if (name.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFE7EDF5).withAlpha(100),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 오른쪽 평가 라벨
                Text(
                  _getMoveLabel(type),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),

                // 아이콘 (SVG)
                const SizedBox(width: 8),
                _buildMoveIcon(type),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoveIcon(String type) {
    final String assetName = 'assets/images/moves/$type.svg';

    // 아이콘이 없거나 로드 실패를 대비해 예외처리
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14), // 아이콘 배경
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(35), width: 1),
      ),
      padding: const EdgeInsets.all(3),
      child: SvgPicture.asset(
        assetName,
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ), // 아이콘 흰색으로
        // 파일이 없을 경우를 대비해 placeholder 처리 가능
        placeholderBuilder: (_) => const SizedBox(),
      ),
    );
  }

  // 컨트롤 버튼 스타일 위젯
  Widget _buildControlButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon),
          tooltip: label,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEvalBar(double eval) {
    // 1. 목표가 되는 widthFactor를 먼저 계산합니다.
    final double targetFactor = (0.5 + (eval / 40)).clamp(0.0, 1.0);

    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.black, // 블랙 영역 (배경)
      ),
      child: TweenAnimationBuilder<double>(
        // 2. 애니메이션의 속도와 부드러움(Curve)을 설정합니다.
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutSine, // 시작과 끝이 부드러운 곡선
        tween: Tween<double>(end: targetFactor),
        builder: (context, value, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            // 3. 계산된 중간값(value)을 widthFactor에 적용합니다.
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}
