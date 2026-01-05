import 'dart:async';
import 'package:flutter/material.dart';
// 기존에 만드신 알림 서비스와 TMAP 서비스 파일들을 import 하세요
import 'package:flutter_project/data/bus_arrival_service.dart';
import 'package:flutter_project/data/transit_service.dart';
import 'package:flutter_project/notifications/notification_service.dart';
import 'package:flutter_project/data/favorite_route.dart';

class TransitGuidanceManager {
  Timer? _refreshTimer;

  // 💡 알림창에 띄울 데이터를 가져오는 함수 (이전 답변에서 주신 로직 통합)
  // 이 함수가 필요로 하는 _selectedFavorite나 _tmapApiKey는 생성자나 파라미터로 받으면 됩니다.
  Future<TransitRouteResult> fetchCurrentRoute(FavoriteRoute fav, String apiKey) {
    final dest = TransitDestination(
      name: fav.end.label.isEmpty ? fav.title : fav.end.label,
      lat: fav.end.lat,
      lon: fav.end.lng,
    );

    final service = TransitService(
      apiKey: apiKey,
      destination: dest,
    );

    return service.fetchRoute(
      startLat: fav.start.lat,
      startLon: fav.start.lng,
      startName: fav.start.label.isEmpty ? fav.title : fav.start.label,
      count: 10,
    );
  }

  // 알림 시작
  void startGuidance({
    required FavoriteRoute favorite,
    required String apiKey,
    required TransitVariant variant
  }) async {
    // 1. 즉시 실행
    await _updateStep(favorite, apiKey, variant);

    // 2. 1분마다 반복 (네이버 지도 실시간 갱신 로직)
    _refreshTimer?.cancel(); // 혹시 이미 돌아가고 있다면 취소
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _updateStep(favorite, apiKey, variant);
    });
  }

  Future<void> _updateStep(FavoriteRoute fav, String key, TransitVariant variant) async {
    try {
      final result = await fetchCurrentRoute(fav, key);
      final summary = result.summaryOf(variant);

      // 알림 서비스 호출
      await TransitNotificationService.showOngoingRouteNotification(
        title: result.title,
        routeSummary: summary.summary,
        arrivalDetail: summary.firstArrivalText,
      );
    } catch (e) {
      print('실시간 알림 업데이트 오류: $e');
    }
  }

  // 안내 종료
  void stopGuidance() {
    _refreshTimer?.cancel();
    TransitNotificationService.dismiss();
  }
}