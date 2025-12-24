import 'package:flutter/material.dart';
import 'userMypage.dart'; // 같은 폴더에 있는 userMypage.dart 파일을 가져옵니다.

void main() {
  runApp(const MyTestApp());
}

class MyTestApp extends StatelessWidget {
  const MyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 디버그 배너 제거
      debugShowCheckedModeBanner: false,
      title: 'My Page Test',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      // 시작 페이지를 우리가 만든 UserMypage로 설정
      home: const UserMypage(),
    );
  }
}