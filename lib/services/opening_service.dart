import 'dart:convert';
import 'package:flutter/services.dart';

class OpeningService {
  static final OpeningService _instance = OpeningService._internal();
  factory OpeningService() => _instance;
  OpeningService._internal();

  List<dynamic> _openings = [];

  // 앱 시작 시 main.dart 등에서 호출 필요
  Future<void> loadOpenings() async {
    final String response = await rootBundle.loadString('openings.list.json');
    _openings = json.decode(response);
  }

  // 현재까지의 move 리스트(예: ["e4", "e5", "Nf3"])와 매칭되는 오프닝 찾기
  Map<String, String> findOpeningName(List<String> moveHistorySan) {
    String nameKo = "미분류 오프닝";
    String nameEn = "Unknown Variation";

    // 정확히 일치하는 오프닝 찾기 (가장 긴 매칭 우선)
    // 리스트를 순회하며 moves 배열이 현재 히스토리와 일치하는지 확인
    for (var opening in _openings) {
      List<dynamic> openingMoves = opening['moves'];

      // 길이가 같고 내용이 모두 같으면 매칭
      if (openingMoves.length == moveHistorySan.length) {
        bool match = true;
        for (int i = 0; i < openingMoves.length; i++) {
          if (openingMoves[i] != moveHistorySan[i]) {
            match = false;
            break;
          }
        }
        if (match) {
          nameKo = opening['name_ko'] ?? nameKo;
          nameEn = opening['name_en'] ?? nameEn;
          break; // 찾았으면 중단
        }
      }
    }
    return {'ko': nameKo, 'en': nameEn};
  }
}
