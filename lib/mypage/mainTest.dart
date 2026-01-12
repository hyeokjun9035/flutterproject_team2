// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'loginPageTest.dart';
// import 'package:flutter_project/firebase_options.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// //테스트 로그인 페이지 메인
// void main() async {
//
//   WidgetsFlutterBinding.ensureInitialized();
//
//   try {
//     await dotenv.load(fileName: ".env");
//     print("✅ .env 로드 성공");
//   } catch (e) {
//     print("❌ .env 로드 실패: $e");
//   }
//
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   runApp(const MyTestApp());
// }
//
// class MyTestApp extends StatelessWidget {
//   const MyTestApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'My Page Test',
//       theme: ThemeData(
//         primarySwatch: Colors.deepPurple,
//         useMaterial3: true,
//       ),
//       home: const LoginPage(),
//     );
//   }
// }