import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 2025-12-23 jgh251223---S
import 'firebase_options.dart';
import 'home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // 2025-12-23 jgh251223---E
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Functions 에뮬레이터로 연결 (개발할 때만)
  FirebaseFunctions.instanceFor(region: 'asia-northeast3')
      .useFunctionsEmulator(Platform.isAndroid ? '10.0.2.2' : 'localhost', 5001);

  runApp(const MyApp());
  //야야야야야야야야야야야야야
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
      ),
      home: const HomePage(),
    );
  }
}
