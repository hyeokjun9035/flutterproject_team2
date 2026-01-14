import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_project/community/CommunityView.dart';
import 'package:flutter_project/mypage/locationSettings.dart';
import 'firebase_options.dart';
import 'home/home_page.dart';
import 'join/login.dart';
import 'package:flutter_project/community/Community.dart';
import 'package:flutter_project/mypage/userMypage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_project/notifications/notions.dart';
import 'package:flutter_project/mypage/DetailMypost.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_project/community/CommunityView.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// -------------------- 위치/토큰 업데이트 --------------------
Future<void> updateUserData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final geo.Position position = await _determinePosition();
    final String? token = await FirebaseMessaging.instance.getToken();

    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'lastLocation': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('✅ [자동 업데이트 성공]');
  } catch (e) {
    debugPrint('❌ [자동 업데이트 실패] 원인: $e');
  }
}

Future<geo.Position> _determinePosition() async {
  final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('위치 서비스가 비활성화되어 있습니다.');
  }

  var permission = await geo.Geolocator.checkPermission();

  if (permission == geo.LocationPermission.denied) {
    permission = await geo.Geolocator.requestPermission();
    if (permission == geo.LocationPermission.denied) {
      return Future.error('위치 권한이 거부되었습니다.');
    }
  }

  if (permission == geo.LocationPermission.deniedForever) {
    return Future.error('위치 권한이 영구적으로 거부되어 설정에서 허용해야 합니다.');
  }

  return geo.Geolocator.getCurrentPosition();
}

// -------------------- 알림 클릭 처리 --------------------
void _goHome() {
  navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (r) => false);
}

void _handleMessage(RemoteMessage message) {
  final postId = (message.data['postId'] ?? '').toString().trim();

  // ✅ postId 있으면 상세, 없으면 홈
  if (postId.isNotEmpty) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => Communityview(docId: postId),
      ),
    );
  } else {
    _goHome();
  }
}

// -------------------- main --------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // 1) Firebase 먼저 초기화
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase 초기화 완료');
  } else {
    Firebase.app(); // 이미 초기화된 경우 기존 앱 사용
    debugPrint('ℹ️ Firebase가 이미 초기화되어 있습니다.');
  }

  // 2) AppCheck는 "가능한 빨리" 활성화 (중요)
  //    + getToken(true) 같은 강제 갱신은 제거 (Too many attempts 방지)
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
    debugPrint('✅ [APPCHECK] activated (debug)');
  } catch (e) {
    debugPrint('⚠️ [APPCHECK] activate failed: $e');
  }

  // 3) FCM 권한/토큰
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  try {
    final String? fcmToken = await messaging.getToken();
    debugPrint('************************************************');
    debugPrint('🔥 [FCM TOKEN] : $fcmToken');
    debugPrint('************************************************');
  } catch (e) {
    debugPrint('❌ [FCM TOKEN ERROR] : $e');
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': newToken,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('✅ [FCM TOKEN REFRESH] 저장 완료: $newToken');
  });

  // 4) 로컬 알림 채널 + 초기화
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'community_notification',
    '교통 제보 알림',
    description: '새로운 교통 제보 게시글에 대한 알림입니다.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payload = (response.payload ?? '').trim();

      if (payload.isNotEmpty) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => Communityview(docId: payload),
          ),
        );
      } else {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (r) => false);
      }
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 5) 포그라운드 수신 시 로컬 알림 표시
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification == null || android == null) return;

    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: 'aimiri3',
          largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
          color: Colors.lightBlueAccent,
          priority: Priority.high,
          importance: Importance.max,
        ),
      ),
      payload: (message.data['postId'] ?? '').toString(),
    );
  });

  // 6) 백그라운드/종료 상태 클릭 처리 + 토픽 구독
  await messaging.subscribeToTopic('community_topic');

  final RemoteMessage? initialMessage =
  await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) _handleMessage(initialMessage);

  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

  // 7) Functions emulator (필요 시만)
  const bool isDebugMode = false;
  if (isDebugMode) {
    FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .useFunctionsEmulator(Platform.isAndroid ? '10.0.2.2' : 'localhost', 5001);
  }

  // 8) 로그인 되면 유저데이터 업데이트 (앱 전체 흐름과 분리)
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      updateUserData();
    }
  });

  runApp(const MyApp());
}

// -------------------- 경로 알림 함수 (그대로 유지) --------------------
Future<void> showRouteNotification({
  required String stationName,
  required String remainingTime,
  required String nextBusInfo,
}) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  AndroidNotificationDetails androidNotificationDetails =
  AndroidNotificationDetails(
    'route_step_channel',
    '경로 안내 알림',
    channelDescription: '실시간 버스 및 경로 정보를 표시합니다.',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: true,
    showWhen: false,
  );

  NotificationDetails notificationDetails =
  NotificationDetails(android: androidNotificationDetails);

  await flutterLocalNotificationsPlugin.show(
    888,
    ' $stationName 정보',
    '정류장까지 $remainingTime | 다음 버스: $nextBusInfo',
    notificationDetails,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/community': (context) => const CommunityPage(),
        '/mypage': (context) => const UserMypage(),
        '/locationSettings': (context) => const LocationSettings(),
        '/notice': (context) => NotificationScreen(),
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
      ),
    );
  }
}
