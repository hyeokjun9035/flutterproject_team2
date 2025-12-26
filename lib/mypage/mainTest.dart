import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'loginPageTest.dart';
import 'package:flutter_project/firebase_options.dart'; // 생성된 옵션 파일

void main() async {
  // 1. Flutter 엔진과 비동기 서비스 연결
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase 초기화 (옵션 설정 추가 필수!)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyTestApp());
}

class MyTestApp extends StatelessWidget {
  const MyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Page Test',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const LoginPage(), // 로그인 페이지로 시작
    );
  }
}