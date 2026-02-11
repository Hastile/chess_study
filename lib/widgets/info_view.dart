// ./lib/widgets/info_view.dart
import 'package:flutter/material.dart';

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
  });

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

            // 실제 기보 연동은 추후 구현
          ],
        ),
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
