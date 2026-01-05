import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TransitNotificationService {
  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const int notificationId = 2025; // 알림 고유 ID

  // 알림창 띄우기 및 업데이트
  static Future<void> showOngoingRouteNotification({
    required String title,
    required String routeSummary,
    required String arrivalDetail,
  }) async {
    // 안드로이드 알림 세부 설정
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'transit_channel', // 채널 ID
      '대중교통 안내',      // 채널 이름
      channelDescription: '실시간 경로 및 버스 도착 정보를 표시합니다.',
      importance: Importance.low, // 업데이트 시 소리 안 나게 함
      priority: Priority.low,
      ongoing: true,      // ❌ 사용자가 옆으로 밀어서 끌 수 없음 (네이버 지도 방식)
      autoCancel: false,  // 클릭해도 사라지지 않음
      onlyAlertOnce: true, // 처음 뜰 때만 소리/진동 발생
      showWhen: false,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      notificationId,
      title,
      '$routeSummary\n$arrivalDetail',
      platformDetails,
    );
  }

  // 안내 종료 시 알림 삭제
  static Future<void> dismiss() async {
    await _notificationsPlugin.cancel(notificationId);
  }
}