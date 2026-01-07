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
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart' as geo;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> updateUserData() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    // Position 앞에 geo. 추가
    geo.Position position = await _determinePosition();
    String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
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
    }
  } catch (e) {
    debugPrint('❌ [자동 업데이트 실패] 원인: $e');
  }
}

//  _determinePosition 함수 수정
Future<geo.Position> _determinePosition() async {
  bool serviceEnabled;
  geo.LocationPermission permission;

  // 1. 위치 서비스 활성화 여부 확인
  serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('위치 서비스가 비활성화되어 있습니다.');
  }

  // 2. 현재 권한 상태 확인
  permission = await geo.Geolocator.checkPermission();

  // 3. 권한이 거부된 경우 요청
  if (permission == geo.LocationPermission.denied) {
    permission = await geo.Geolocator.requestPermission();
    if (permission == geo.LocationPermission.denied) {
      return Future.error('위치 권한이 거부되었습니다.');
    }
  }

  // 4. 영구적으로 거부된 경우
  if (permission == geo.LocationPermission.deniedForever) {
    return Future.error('위치 권한이 영구적으로 거부되어 설정에서 허용해야 합니다.');
  }

  // 5. 모든 관문을 통과하면 현재 위치 반환
  return await geo.Geolocator.getCurrentPosition();
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('************************************************');
    debugPrint('🔥 [FCM TOKEN] : $fcmToken');
    debugPrint('************************************************');
  } catch (e) {
    debugPrint('❌ [FCM TOKEN ERROR] : $e');
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // 260106 주석처리
  // final t = await FirebaseAppCheck.instance.getToken(true);
  // debugPrint('[APPCHECK TOKEN] ${t ?? "NULL"}');

  // App Check 토큰 가져오기 실패 시 앱이 멈추지 않도록 예외 처리 추가 260106 전경환추가
  try {
    final t = await FirebaseAppCheck.instance.getToken(true);
    debugPrint('[APPCHECK TOKEN] ${t ?? "NULL"}');
  } catch (e) {
    debugPrint('[APPCHECK ERROR] $e');
  }

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

      // ✅ jgh260106 수정: 컬러 이미지를 오른쪽에 고정하고 왼쪽 아이콘 문제를 해결하기 위해 largeIcon 방식 적용
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            // icon: android.smallIcon, //jgh260106주석처리
            // jgh260106 추가
            icon: 'ic_notification', // 작은 아이콘 (배경 투명 흰색 실루엣 이미지여야 하얀 네모가 안 생김)
            // ✅ 컬러 이미지를 알림창 오른쪽에 항상 보이도록 설정
            largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
            // ✅ 왼쪽 원형 배경색을 브랜드 컬러(파란색 계열)로 지정
            color: const Color(0xFF1976D2),
            priority: Priority.high,
            importance: Importance.max,
            // MessagingStyleInformation은 요약 시 이미지를 숨기므로 제거함
          ),
        ),
        // jgh260106 수정 끝
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
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      updateUserData();
    }
  });

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
