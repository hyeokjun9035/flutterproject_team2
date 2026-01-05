import 'dart:convert';
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

class BusArrivalService {
  BusArrivalService({required this.serviceKey, http.Client? client})
      : _client = client ?? http.Client();

  final String serviceKey;
  final http.Client _client;

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
    required String routeNo, // 예: "1400"
  }) async {
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

    final res = await _client.get(uri).timeout(const Duration(seconds: 3));
    final decoded = jsonDecode(res.body);

    final items = decoded?['response']?['body']?['items']?['item'];
    if (items == null) return null;

    final list = (items is List) ? items : [items];

    // routeNo 일치하는 것 중 가장 빠른 arrtime 선택
    Map<String, dynamic>? best;
    int bestArr = 1 << 30;
    String _normRoute(String s) => s
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('번', '')
        .replaceAll(RegExp(r'[^0-9A-Za-z가-힣-]'), '')
        .toUpperCase();
    final target = _normRoute(routeNo);

    bool seen = false;

    for (final it in list) {
      final rn = _normRoute('${it['routeno'] ?? ''}');
      if (rn != target) continue;

      seen = true;

      final arrSec = int.tryParse('${it['arrtime'] ?? ''}') ?? 0;
      if (arrSec > 0 && arrSec < bestArr) {
        bestArr = arrSec;
        best = Map<String, dynamic>.from(it);
      }
    }

    if (best == null) {
      if (seen) return '버스 $routeNo · 도착 정보 없음';
      return null;
    }

    final min = (bestArr / 60).ceil();
    final prev = int.tryParse('${best['arrprevstationcnt'] ?? ''}') ?? -1;

    final prevText = (prev >= 0) ? ' ($prev정거장 전)' : '';
    return '버스 $routeNo · ${min}분 후$prevText';
  }
}
