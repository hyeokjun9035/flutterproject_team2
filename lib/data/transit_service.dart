// 2025-12-23 jgh251223---S
import 'dart:convert';

import 'package:http/http.dart' as http;
enum TransitVariant { minWalk, fastest, minTransfer }

class TransitItinerarySummary {
  const TransitItinerarySummary({
    required this.totalMinutes,
    required this.walkMinutes,
    required this.transfers,
    required this.firstArrivalText,
    required this.secondArrivalText,
  });

  final int totalMinutes;
  final int walkMinutes;
  final int transfers;
  final String firstArrivalText;
  final String secondArrivalText;

  String get summary => '총 ${totalMinutes}분 · 도보 ${walkMinutes}분 · 환승 $transfers';
}

/// 목적지 정보
class TransitDestination {
  const TransitDestination({
    required this.name,
    required this.lat,
    required this.lon,
  });

  final String name;
  final double lat;
  final double lon;
}

/// TMAP 대중교통 경로 결과(간략 요약만 사용)
class TransitRouteResult {
  const TransitRouteResult({
    required this.title,
    required this.raw,
    required this.itineraries,
    required this.idxFastest,
    required this.idxMinWalk,
    required this.idxMinTransfer,
  });

  final String title;
  final Map<String, dynamic> raw;
  final List<TransitItinerarySummary> itineraries;

  final int idxFastest;
  final int idxMinWalk;
  final int idxMinTransfer;

  int indexOf(TransitVariant v) => switch (v) {
    TransitVariant.fastest => idxFastest,
    TransitVariant.minWalk => idxMinWalk,
    TransitVariant.minTransfer => idxMinTransfer,
  };

  TransitItinerarySummary summaryOf(TransitVariant v) => itineraries[indexOf(v)];

  /// API 키가 없을 때 사용할 샘플 데이터
  // factory TransitRouteResult.placeholder(String destinationName) {
  //   return TransitRouteResult(
  //     title: '출근 / 즐겨찾기 루트 #1 ($destinationName)',
  //     totalMinutes: 42,
  //     walkMinutes: 4,
  //     transfers: 1,
  //     firstArrivalText: '버스 ???분 후',
  //     secondArrivalText: '지하철 ???분 후',
  //     raw: const {},
  //     itineraries: []
  //   );
  // }

  /// TMAP 응답을 최대한 안전하게 파싱
  factory TransitRouteResult.fromTmap(
      Map<String, dynamic> json, {
        required String destinationName,
      }) {
    final meta = (json['metaData'] ?? json['meta']) as Map? ?? {};
    final plan = (meta['plan'] ?? {}) as Map;
    final itinerariesRaw = (plan['itineraries'] ?? []) as List;

    if (itinerariesRaw.isEmpty) {
      final message = meta['error']?['message'] ?? '경로가 없습니다. ($destinationName)';
      throw Exception(message.toString());
    }

    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    int toMinutes(int seconds) => ((seconds / 60).round()).clamp(0, 1 << 30);

    String arrivalTextFromLeg(Map<String, dynamic> leg) {
      final mode = (leg['mode'] ?? '').toString().toUpperCase();
      if (mode == 'WALK') return '';
      final route = leg['route'] ?? leg['routeName'] ?? '';
      final headsign = leg['headsign'] ?? '';
      final interval = asInt(leg['interval']); // ※ 이건 보통 배차간격(실시간 아님)
      final sb = StringBuffer();
      if (mode.isNotEmpty) sb.write(mode == 'BUS' ? '버스' : mode);
      if ('$route'.isNotEmpty) sb.write(' $route');
      if ('$headsign'.isNotEmpty) sb.write(' $headsign');
      if (interval > 0) sb.write(' ${interval}분 간격');
      return sb.toString().trim();
    }

    TransitItinerarySummary parseOne(Map<String, dynamic> it) {
      final totalSec = asInt(it['totalTime']);
      final walkSec  = asInt(it['totalWalkTime']);
      final transfers = asInt(it['transferCount'] ?? it['transfer'] ?? it['transfers']);

      final legs = (it['legs'] ?? []) as List;
      final legTexts = legs
          .map((e) => arrivalTextFromLeg(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.isNotEmpty)
          .toList();

      return TransitItinerarySummary(
        totalMinutes: toMinutes(totalSec),
        walkMinutes:  toMinutes(walkSec),
        transfers: transfers,
        firstArrivalText: legTexts.isNotEmpty ? legTexts.first : '',
        secondArrivalText: legTexts.length >= 2 ? legTexts[1] : '',
      );
    }

    final summaries = itinerariesRaw
        .map((e) => parseOne(Map<String, dynamic>.from(e as Map)))
        .toList();

    // ✅ 3개 대표 인덱스 고르기
    int idxFast = 0;
    int idxWalk = 0;
    int idxTr = 0;

    for (int i = 1; i < summaries.length; i++) {
      final s = summaries[i];

      if (s.totalMinutes < summaries[idxFast].totalMinutes) idxFast = i;
      if (s.walkMinutes  < summaries[idxWalk].walkMinutes)  idxWalk = i;

      final curTr = s.transfers;
      final bestTr = summaries[idxTr].transfers;
      if (curTr < bestTr) {
        idxTr = i;
      } else if (curTr == bestTr) {
        // tie-break: time -> walk
        if (s.totalMinutes < summaries[idxTr].totalMinutes) idxTr = i;
        else if (s.totalMinutes == summaries[idxTr].totalMinutes &&
            s.walkMinutes < summaries[idxTr].walkMinutes) idxTr = i;
      }
    }

    return TransitRouteResult(
      title: '출근 / 즐겨찾기 루트 ($destinationName)',
      raw: json,
      itineraries: summaries,
      idxFastest: idxFast,
      idxMinWalk: idxWalk,
      idxMinTransfer: idxTr,
    );
  }
}

class TransitService {
  TransitService({
    required this.apiKey,
    required this.destination,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final TransitDestination destination;
  final http.Client _client;

  /// 현재 위치 → 목적지 경로 조회
  Future<TransitRouteResult> fetchRoute({
    required double startLat,
    required double startLon,
    required String startName,
    DateTime? searchTime,
    int count = 10,
    int lang = 0,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('TMAP API 키가 설정되지 않았습니다.');
    }

    // TMAP은 searchDttm을 요구(미지정 시 현재 시각 사용)
    final effectiveSearchTime = searchTime ?? DateTime.now();

    String _fmt(DateTime dt) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y$m$d$h$mm'; // yyyyMMddHHmm
    }

    // Postman 예시와 정확히 동일하게 구성
    // Postman: startX/startY/endX/endY는 문자열, count/lang은 숫자
    final bodyMap = <String, dynamic>{
      'startX': startLon.toString(),
      'startY': startLat.toString(),
      'endX': destination.lon.toString(),
      'endY': destination.lat.toString(),
      'count': count,
      'lang': lang,
      'format': 'json',
      'searchDttm': _fmt(effectiveSearchTime),
    };

    // JSON 인코딩 (Postman과 동일)
    final bodyJson = jsonEncode(bodyMap);

    // Postman과 동일: URL 끝에 슬래시 포함
    final uri = Uri.https('apis.openapi.sk.com', '/transit/routes/');

    // Postman과 동일한 헤더 (순서도 동일)
    final headers = {
      'Accept': 'application/json',
      'appKey': apiKey,
      'Content-Type': 'application/json',
    };

    final res = await _client.post(
      uri,
      headers: headers,
      body: bodyJson,
    );

    if (res.statusCode >= 400) {
      // TMAP 에러 응답 전체 구조 확인
      final errorBody = res.body;
      try {
        final errorJson = jsonDecode(errorBody) as Map<String, dynamic>;
        // TMAP은 result.message 형태로 에러 반환
        final result = errorJson['result'] as Map<String, dynamic>?;
        final errorMsg = result?['message'] ??
                        errorJson['errorMessage'] ??
                        errorJson['message'] ??
                        errorBody;
        throw Exception('TMAP 응답 오류(${res.statusCode}): $errorBody');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('TMAP 응답 오류(${res.statusCode}): ${res.body}');
      }
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('TMAP 응답을 해석할 수 없습니다.');
    }

    return TransitRouteResult.fromTmap(
      decoded,
      destinationName: destination.name,
    );
  }
}
// 2025-12-23 jgh251223---E

