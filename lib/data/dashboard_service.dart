import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'models.dart';
import 'dart:io';

class DashboardService {
  DashboardService({required this.region});

  final String region;

  FirebaseFunctions get _functions {
    final f = FirebaseFunctions.instanceFor(region: region);
    // ✅ Android Emulator면 10.0.2.2
    f.useFunctionsEmulator(Platform.isAndroid ? '10.0.2.2' : 'localhost', 5001);
    return f;
  }

  Future<Map<String, dynamic>> ping() async {
    final res = await _functions.httpsCallable('getDashboard').call({'ping': true});
    return Map<String, dynamic>.from(res.data);
  }

  /// nx, ny는 (GPS → 격자 변환 or 행정동 매핑)으로 구해둔 값을 넘긴다고 가정
  Future<DashboardData> fetchDashboard({
    required int nx,
    required int ny,
    required String locationName,
    required String baseDate, // yyyyMMdd
    required String baseTime, // HHmm
  }) async {
    final callable = _functions.httpsCallable('getDashboard');

    final res = await callable.call({
      'nx': nx,
      'ny': ny,
      'base_date': baseDate,
      'base_time': baseTime,
      'locationName': locationName,
    });

    final data = Map<String, dynamic>.from(res.data as Map);

    // === 1) KMA 실황/예보 파싱 (items 배열 형태 가정) ===
    // nowItems: [{category:"T1H", obsrValue:"1"}, ...]
    final nowItems = (data['weatherNow'] ?? data['weather'] ?? []) as List;
    final nowMap = <String, String>{};
    for (final it in nowItems) {
      final m = Map<String, dynamic>.from(it as Map);
      final cat = (m['category'] ?? '').toString();
      final val = (m['obsrValue'] ?? m['fcstValue'] ?? '').toString();
      if (cat.isNotEmpty && val.isNotEmpty) nowMap[cat] = val;
    }

    double? _d(String k) => double.tryParse(nowMap[k] ?? '');
    int? _i(String k) => int.tryParse(nowMap[k] ?? '');

    final now = WeatherNow(
      temp: _d('T1H') ?? _d('TMP'),
      humidity: _d('REH'),
      wind: _d('WSD'),
      sky: _i('SKY'),
      pty: _i('PTY'),
      rn1: _d('RN1'),
    );

    // === 2) 시간대별 예보 (hourlyFcst 배열을 Functions에서 만들어 주는 걸 추천) ===
    // hourlyFcst: [{timeLabel:"09시", sky:1, pty:0, temp:7.0}, ...]
    final hourlyRaw = (data['hourlyFcst'] ?? []) as List;
    final hourly = hourlyRaw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return HourlyForecast(
        timeLabel: (m['timeLabel'] ?? '').toString(),
        sky: m['sky'] is int ? m['sky'] as int : int.tryParse('${m['sky']}'),
        pty: m['pty'] is int ? m['pty'] as int : int.tryParse('${m['pty']}'),
        temp: m['temp'] is num ? (m['temp'] as num).toDouble() : double.tryParse('${m['temp']}'),
      );
    }).toList();

    // === 3) 특보 목록 ===
    // alerts: [{title:"호우주의보", region:"서울", timeText:"~"}]
    final alertsRaw = (data['alerts'] ?? []) as List;
    final alerts = alertsRaw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return WeatherAlert(
        title: (m['title'] ?? m['warnVar'] ?? '특보').toString(),
        region: (m['region'] ?? m['areaName']).toString(),
        timeText: (m['timeText'] ?? m['announceTime']).toString(),
      );
    }).toList();

    // === 4) 대기질 ===
    // air: {gradeText:"보통", pm10:32, pm25:18}
    final airRaw = Map<String, dynamic>.from((data['air'] ?? {}) as Map);
    final air = AirQuality(
      gradeText: (airRaw['gradeText'] ?? '정보없음').toString(),
      pm10: airRaw['pm10'] is int ? airRaw['pm10'] as int : int.tryParse('${airRaw['pm10']}'),
      pm25: airRaw['pm25'] is int ? airRaw['pm25'] as int : int.tryParse('${airRaw['pm25']}'),
    );

    // === 업데이트 시각 ===
    final updatedAt =
    (DateTime.tryParse((data['updatedAt'] ?? '').toString()) ?? DateTime.now())
        .toLocal();

    return DashboardData(
      locationName: locationName,
      updatedAt: updatedAt,
      now: now,
      hourly: hourly,
      alerts: alerts,
      air: air,
    );
  }

  Future<DashboardData> fetchDashboardByLatLon({
    required double lat,
    required double lon,
    required String locationName,
    required String airAddr,
    required String administrativeArea
  }) async {
    final callable = _functions.httpsCallable(
        'getDashboard',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20))
    );

    final res = await callable.call({
      'lat': lat,
      'lon': lon,
      'locationName': locationName,
      'addr': airAddr,
      'administrativeArea': administrativeArea,
    });
    debugPrint('📡 getDashboard call lat=$lat lon=$lon at=${DateTime.now()}');

    final data = Map<String, dynamic>.from(res.data as Map);
    // === 아래 파싱 로직은 기존과 동일 ===
    final nowItems = (data['weatherNow'] ?? data['weather'] ?? []) as List;
    final nowMap = <String, String>{};
    for (final it in nowItems) {
      final m = Map<String, dynamic>.from(it as Map);
      final cat = (m['category'] ?? '').toString();
      final val = (m['obsrValue'] ?? m['fcstValue'] ?? '').toString();
      if (cat.isNotEmpty && val.isNotEmpty) nowMap[cat] = val;
    }

    double? _d(String k) => double.tryParse(nowMap[k] ?? '');
    int? _i(String k) => int.tryParse(nowMap[k] ?? '');

    final now = WeatherNow(
      temp: _d('T1H') ?? _d('TMP'),
      humidity: _d('REH'),
      wind: _d('WSD'),
      sky: _i('SKY'),
      pty: _i('PTY'),
      rn1: _d('RN1'),
    );

    final hourlyRaw = (data['hourlyFcst'] ?? []) as List;
    final hourly = hourlyRaw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return HourlyForecast(
        timeLabel: (m['timeLabel'] ?? '').toString(),
        sky: m['sky'] is int ? m['sky'] as int : int.tryParse('${m['sky']}'),
        pty: m['pty'] is int ? m['pty'] as int : int.tryParse('${m['pty']}'),
        temp: m['temp'] is num ? (m['temp'] as num).toDouble() : double.tryParse('${m['temp']}'),
      );
    }).toList();

    final alertsRaw = (data['alerts'] ?? []) as List;
    final alerts = alertsRaw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return WeatherAlert(
        title: (m['title'] ?? m['warnVar'] ?? '특보').toString(),
        region: (m['region'] ?? m['areaName']).toString(),
        timeText: (m['timeText'] ?? m['announceTime']).toString(),
      );
    }).toList();

    final weeklyRaw = (data['weekly'] ?? []) as List;
    final weekly = weeklyRaw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return DailyForecast(
        date: (m['date'] ?? '').toString(),
        min: m['min'] is num ? (m['min'] as num).toDouble() : double.tryParse('${m['min']}'),
        max: m['max'] is num ? (m['max'] as num).toDouble() : double.tryParse('${m['max']}'),
        pop: m['pop'] is int ? m['pop'] as int : int.tryParse('${m['pop']}'),
        sky: m['sky'] is int ? m['sky'] as int : int.tryParse('${m['sky']}'),
        pty: m['pty'] is int ? m['pty'] as int : int.tryParse('${m['pty']}'),
        wfText: m['wfText']?.toString(),
        wfAm: m['wfAm']?.toString(),
        wfPm: m['wfPm']?.toString(),
        popAm: m['popAm'] is int ? m['popAm'] as int : int.tryParse('${m['popAm']}'),
        popPm: m['popPm'] is int ? m['popPm'] as int : int.tryParse('${m['popPm']}'),
      );
    }).toList();


    final airRaw = Map<String, dynamic>.from((data['air'] ?? {}) as Map);
    final air = AirQuality(
      gradeText: (airRaw['gradeText'] ?? '정보없음').toString(),
      pm10: airRaw['pm10'] is int ? airRaw['pm10'] as int : int.tryParse('${airRaw['pm10']}'),
      pm25: airRaw['pm25'] is int ? airRaw['pm25'] as int : int.tryParse('${airRaw['pm25']}'),
    );

    final updatedAt =
    (DateTime.tryParse((data['updatedAt'] ?? '').toString()) ?? DateTime.now())
        .toLocal();

    return DashboardData(
      locationName: locationName,
      updatedAt: updatedAt,
      now: now,
      hourly: hourly,
      alerts: alerts,
      air: air,
      weekly: weekly,
    );
  }

}
