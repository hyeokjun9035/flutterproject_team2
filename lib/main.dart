import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_project/mypage/locationSettings.dart';
// import 'package:flutter_project/admin/admin_home_page.dart';
import 'firebase_options.dart';
import 'home/home_page.dart';
import 'join/login.dart'; // ✅ LoginPage 파일 경로에 맞게 수정!
import 'package:flutter_project/community/Community.dart';
import 'package:flutter_project/mypage/userMypage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_project/notifications/notions.dart';
import 'package:flutter_project/mypage/DetailMypost.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. 권한 요청
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // 2. 알림 채널 설정 (Android)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'community_notification',
    '교통 제보 알림',
    description: '새로운 교통 제보 게시글에 대한 알림입니다.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 3. ✅ [필수 추가] 로컬 알림 플러그인 초기화
  // 이 코드가 있어야 알림을 눌렀을 때 반응합니다.
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // ✅ 여기서 클릭 시 이동 처리
      if (response.payload != null && response.payload!.isNotEmpty) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => Detailmypost(
              postId: response.payload!,
              imageUrl: '',
              postData: const {},
            ),
          ),
        );
      }
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 4. ✅ [추가] 포그라운드 수신 리스너
  // 앱이 켜져 있을 때도 알림을 띄우고 싶다면 이 코드가 필요합니다.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: android.smallIcon,
          ),
        ),
        payload: message.data['postId'], // 클릭 시 전달할 데이터
      );
    }
  });

  // 5. 백그라운드/종료 상태에서 클릭 처리
  await messaging.subscribeToTopic('community_topic');

  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) _handleMessage(initialMessage);

  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

  // ✅ 에뮬레이터 설정을 끄고 실제 서버를 사용하도록 수정
  bool isDebugMode = false; // 👈 true에서 false로 변경 260106jgh
  if (isDebugMode) {
    FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .useFunctionsEmulator(Platform.isAndroid ? '10.0.2.2' : 'localhost', 5001);
  }

  runApp(const MyApp());


}

void _handleMessage(RemoteMessage message) {
  final String? postId = message.data['postId'];

  if (postId != null && postId.isNotEmpty) {
    // navigatorKey를 사용하여 전역적으로 상세 페이지로 push
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => Detailmypost(
          postId: postId,
          imageUrl: '',
          postData: const {}, // Detailmypost가 내부에서 스스로 데이터를 가져옴
        ),
      ),
    );
  }
}

//함수 추가
Future<void> showRouteNotification({
  required String stationName,
  required String remainingTime,
  required String nextBusInfo,
}) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 안드로이드 알림 설정
  AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
    'route_step_channel', // 채널 ID
    '경로 안내 알림', // 채널 이름
    channelDescription: '실시간 버스 및 경로 정보를 표시합니다.',
    importance: Importance.low, // 소리 없이 조용히 업데이트
    priority: Priority.low,
    ongoing: true, // 사용자가 삭제 불가 (안내 중일 때)
    autoCancel: false,
    onlyAlertOnce: true, // 업데이트 시 소리/진동 한 번만
    showWhen: false, // 시간 대신 정보 위주로 표시
  );

  NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);

  // 알림 표시/업데이트 (ID를 888 등으로 고정하면 해당 알림만 계속 바뀜)
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

      // ✅ 라우트는 유지하되, 시작은 로그인으로
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/community': (context) => const CommunityPage(),
        '/mypage': (context) => const UserMypage(),
        '/locationSettings': (context) => const LocationSettings(),
        '/notice': (context) =>  NotificationScreen(),
      },

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
      ),
    );
  }
}
