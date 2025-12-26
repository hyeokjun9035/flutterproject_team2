import 'dart:math' as math;
import '../data/models.dart';

class DashboardCache {
  // ✅ 날씨 대시보드 캐시
  static DashboardData? data;
  static DateTime? fetchedAt;

  // ✅ 위치/주소 캐시(역지오코딩 비용 줄이기)
  static double? lat;
  static double? lon;
  static String? locationLabel;       // 화면 표시용(부평역 등)
  static String? airAddr;             // 대기질 조회용(인천광역시 부평구 등)
  static String? administrativeArea;  // 예: 인천광역시
  static DateTime? geocodedAt;

  static bool isFresh({Duration ttl = const Duration(minutes: 8)}) {
    if (data == null || fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt!) < ttl;
  }

  static bool canReuseGeocode({
    double? newLat,
    double? newLon,
    double distMeter = 600,
    Duration ttl = const Duration(hours: 6),
  }) {
    if (lat == null || lon == null) return false;
    if (geocodedAt == null) return false;
    if (DateTime.now().difference(geocodedAt!) > ttl) return false;

    if (newLat == null || newLon == null) return false;

    final d = _distanceMeters(lat!, lon!, newLat, newLon);
    return d <= distMeter;
  }

  static void saveDashboard(DashboardData d) {
    data = d;
    fetchedAt = DateTime.now();
  }

  static void saveGeocode({
    required double lat,
    required double lon,
    required String locationLabel,
    required String airAddr,
    required String administrativeArea,
  }) {
    DashboardCache.lat = lat;
    DashboardCache.lon = lon;
    DashboardCache.locationLabel = locationLabel;
    DashboardCache.airAddr = airAddr;
    DashboardCache.administrativeArea = administrativeArea;
    DashboardCache.geocodedAt = DateTime.now();
  }

  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    // 간단 하버사인
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
            Math.cos(_deg2rad(lat1)) * Math.cos(_deg2rad(lat2)) *
                (Math.sin(dLon / 2) * Math.sin(dLon / 2));
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double d) => d * 3.141592653589793 / 180.0;
}

// dart:math 없이 쓰려고 간단 래퍼
class Math {
  static double sin(double x) => Math._sin(x);
  static double cos(double x) => Math._cos(x);
  static double sqrt(double x) => Math._sqrt(x);
  static double atan2(double y, double x) => Math._atan2(y, x);

  // 아래는 dart:math 쓰는 게 깔끔하지만, 프로젝트에서 이미 쓰고 있으면 dart:math import로 바꿔도 됨.
  static double _sin(double x) => math.sin(x);
  static double _cos(double x) => math.cos(x);
  static double _sqrt(double x) => math.sqrt(x);
  static double _atan2(double y, double x) => math.atan2(y, x);
}
