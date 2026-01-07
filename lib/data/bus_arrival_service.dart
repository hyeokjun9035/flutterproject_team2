import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class TagoStop {
  final String cityCode;
  final String nodeId;
  final String name;
  final double lat;
  final double lon;

  TagoStop({
    required this.cityCode,
    required this.nodeId,
    required this.name,
    required this.lat,
    required this.lon,
  });
}

class BusArrivalMatch {
  final String routeId;
  final String routeNo;
  final int arrSec;
  final int prevStops;

  BusArrivalMatch({
    required this.routeId,
    required this.routeNo,
    required this.arrSec,
    required this.prevStops,
  });

  String toText() {
    final min = (arrSec / 60).ceil();
    final prevText = (prevStops >= 0) ? ' (${prevStops}정거장 전)' : '';
    return '버스 $routeNo · ${min}분 후$prevText';
  }
}

class BusArrivalService {
  BusArrivalService({required this.serviceKey, http.Client? client})
      : _client = client ?? http.Client();

  final String serviceKey;
  final http.Client _client;

  String _normRoute(String s) => s
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('번', '')
      .toUpperCase()
      .replaceAll(RegExp(r'[^0-9A-Z가-힣-]'), '');

  Future<TagoStop?> findNearestStop({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.https(
      'apis.data.go.kr',
      '/1613000/BusSttnInfoInqireService/getCrdntPrxmtSttnList',
      {
        'serviceKey': serviceKey,
        '_type': 'json',
        'gpsLati': lat.toString(),
        'gpsLong': lon.toString(),
        'numOfRows': '20',
        'pageNo': '1',
      },
    );

    final res = await _client.get(uri).timeout(const Duration(seconds: 3));
    final decoded = jsonDecode(res.body);

    final items = decoded?['response']?['body']?['items']?['item'];
    if (items == null) return null;

    final list = (items is List) ? items : [items];
    if (list.isEmpty) return null;

    // 가장 가까운 정류장을 고르는 간단 버전(좌표 기준)
    TagoStop? best;
    double bestDist = double.infinity;

    for (final it in list) {
      final city = '${it['citycode'] ?? ''}';
      final node = '${it['nodeid'] ?? ''}';
      final name = '${it['nodenm'] ?? ''}';
      final sLat = double.tryParse('${it['gpslati'] ?? ''}') ?? 0;
      final sLon = double.tryParse('${it['gpslong'] ?? ''}') ?? 0;
      if (city.isEmpty || node.isEmpty) continue;

      final d = (lat - sLat) * (lat - sLat) + (lon - sLon) * (lon - sLon);
      if (d < bestDist) {
        bestDist = d;
        best = TagoStop(cityCode: city, nodeId: node, name: name, lat: sLat, lon: sLon);
      }
    }
    return best;
  }

  Future<List<TagoStop>> findNearbyStops({
    required double lat,
    required double lon,
    int maxStops = 8,
  }) async {
    final uri = Uri.https(
      'apis.data.go.kr',
      '/1613000/BusSttnInfoInqireService/getCrdntPrxmtSttnList',
      {
        'serviceKey': serviceKey,
        '_type': 'json',
        'gpsLati': lat.toString(),
        'gpsLong': lon.toString(),
        'numOfRows': '50',
        'pageNo': '1',
      },
    );

    final res = await _client.get(uri).timeout(const Duration(seconds: 3));
    final decoded = jsonDecode(res.body);

    final items = decoded?['response']?['body']?['items']?['item'];
    if (items == null) return [];

    final list = (items is List) ? items : [items];

    final stops = <TagoStop>[];
    for (final it in list) {
      final city = '${it['citycode'] ?? ''}';
      final node = '${it['nodeid'] ?? ''}';
      final name = '${it['nodenm'] ?? ''}';
      final sLat = double.tryParse('${it['gpslati'] ?? ''}');
      final sLon = double.tryParse('${it['gpslong'] ?? ''}');
      if (city.isEmpty || node.isEmpty || sLat == null || sLon == null) continue;

      stops.add(TagoStop(cityCode: city, nodeId: node, name: name, lat: sLat, lon: sLon));
    }

    stops.sort((a, b) {
      final da = (lat - a.lat) * (lat - a.lat) + (lon - a.lon) * (lon - a.lon);
      final db = (lat - b.lat) * (lat - b.lat) + (lon - b.lon) * (lon - b.lon);
      return da.compareTo(db);
    });

    return stops.take(maxStops).toList();
  }

  Future<String?> fetchNextArrivalText({
    required String cityCode,
    required String nodeId,
    required String routeNo,
  }) async {
    try {
      final uri = Uri.https(
        'apis.data.go.kr',
        '/1613000/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList',
        {
          'serviceKey': serviceKey,
          '_type': 'json',
          'cityCode': cityCode,
          'nodeId': nodeId,
          'numOfRows': '200',
          'pageNo': '1',
        },
      );

      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException('tago arrival timeout'));

      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body);
      final items = decoded?['response']?['body']?['items']?['item'];
      if (items == null) return null;

      final list = (items is List) ? items : [items];

      // ✅ routeNo에 한글이 섞인 경우(예: 종로09)만 한글 유지
      final keepHangul = RegExp(r'[가-힣]').hasMatch(routeNo);

      String normRoute(String s) {
        var out = s.replaceAll(RegExp(r'\s+'), '').replaceAll('번', '').toUpperCase();

        // ✅ target이 한글 포함일 때만 한글을 비교에 포함
        out = out.replaceAll(
          RegExp(keepHangul ? r'[^0-9A-Z가-힣-]' : r'[^0-9A-Z-]'),
          '',
        );

        // ✅ "0402" 같은 케이스 대비: 구간별 선행 0 제거
        final parts = out.split('-').map((seg) {
          final t = seg.replaceFirst(RegExp(r'^0+(?=\d)'), '');
          return t;
        }).toList();
        return parts.join('-');
      }

      final target = normRoute(routeNo);

      Map<String, dynamic>? best;
      int bestArr = 1 << 30;
      bool seen = false;

      for (final it in list) {
        final rn = normRoute('${it['routeno'] ?? ''}');
        if (rn != target) continue;

        seen = true;

        final arrSec = int.tryParse('${it['arrtime'] ?? ''}') ?? 0;
        if (arrSec > 0 && arrSec < bestArr) {
          bestArr = arrSec;
          best = Map<String, dynamic>.from(it);
        }
      }

      if (best == null) {
        // ✅ 해당 정류장에 노선은 있는데(=seen) 지금 도착예정이 없을 수 있음
        if (seen) return '버스 $routeNo · 도착 정보 없음';
        return null;
      }

      final min = (bestArr / 60).ceil();
      final prev = int.tryParse('${best['arrprevstationcnt'] ?? ''}') ?? -1;
      final prevText = (prev >= 0) ? ' ($prev정거장 전)' : '';
      return '버스 $routeNo · ${min}분 후$prevText';
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
