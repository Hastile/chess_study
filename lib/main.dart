// ./lib/main.dart
import 'dart:io'; // Platform 확인을 위해 추가
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // 추가
import 'screen/chess_board_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // --- [데스크톱 DB 초기화 코드 추가] ---
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit(); // FFI 초기화
    databaseFactory = databaseFactoryFfi; // DB 팩토리 설정
  }
  // ----------------------------------
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    center: true,
    title: "Chess Opening Study",
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });

  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        // Chess.com 스타일의 메인 배경색 (짙은 회색)
        scaffoldBackgroundColor: const Color(0xFF302E2B),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF302E2B), // 앱바도 배경과 통일
          elevation: 0, // 그림자 없애서 플랫하게
        ),

        // 텍스트 테마도 약간 부드럽게
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFC3C3C3)),
        ),
        useMaterial3: true,
      ),
      home: const ChessBoardScreen(),
    );
  }
}
