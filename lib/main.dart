import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter_project/admin/admin_home_page.dart';
import 'firebase_options.dart';
import 'home/home_page.dart';
import 'join/login.dart'; // ✅ LoginPage 파일 경로에 맞게 수정!
import 'package:flutter_project/community/Community.dart';
import 'package:flutter_project/mypage/userMypage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 없을 수도 있으면 try/catch로 안전하게
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Functions 에뮬레이터로 연결 (개발할 때만)
  FirebaseFunctions.instanceFor(region: 'asia-northeast3')
      .useFunctionsEmulator(Platform.isAndroid ? '10.0.2.2' : 'localhost', 5001);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Dashboard',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ko'),
      ],


      // ✅ 라우트는 유지하되, 시작은 로그인으로
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/community': (context) => const CommunityPage(),
        '/mypage': (context) => const UserMypage(),
        // '/notice': (context) => const NoticePage(),
      },

      // ✅ 여기 추가: /home은 arguments로 uid 받아서 생성
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          debugPrint("✅ /home args = ${settings.arguments}");
          final uid = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => HomePage(userUid: uid));
        }
        return null;
      },

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
      ),
    );
  }
}
