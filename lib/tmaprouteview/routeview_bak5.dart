import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../headandputter/putter.dart'; //jgh251226
import 'dart:ui' as ui; //251229
import 'package:flutter/services.dart'; //251229

class Routeview extends StatefulWidget {
  final Map<String, dynamic> raw;
  const Routeview({super.key, required this.raw});

  @override
  State<Routeview> createState() => _RouteviewState();
}

class _RouteviewState extends State<Routeview> {
  List<_LegSegment> segments = const [];
  _LegSummary summary = const _LegSummary.empty();
  String debugMsg = 'init...';
  BitmapDescriptor? _cctvIcon; //251229


  //251229
  Future<BitmapDescriptor> _bmpFromAsset(String path, int targetWidth) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: targetWidth, // ✅ 이 값으로 크기 조절
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }


  //251229
  Future<void> _loadMarkerIcons() async {
    try {
      final icon = await _bmpFromAsset('assets/icons/cctv.png', 40); // ✅ 48~96 사이로 조절 추천
      if (!mounted) return;
      setState(() => _cctvIcon = icon);
    } catch (e) {
      // 실패시 기본아이콘 사용
    }
  }



  // ✅ CCTV  jgh251226
  final Set<Marker> _cctvMarkers = {};
  // final Map<String, _CctvItem> _cctvByMarkerId = {};
  // TODO: 네가 발급받은 ITS apiKey 넣을꺼임 언젠가.... 아직은 안넣음
  static const String _itsApiKey = 'a721e634ba9643cda7a97bf7af8b52c6';
  bool _loadingCctv = false;
  String _cctvDebug = '';


  GoogleMapController? _mapCtrl;

  // ✅ 지도 조작 중에는 부모 스크롤을 잠깐 막기 위한 플래그
  bool _isMapInteracting = false;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();   // ✅ 추가 251229
    _buildSegments();
  }

  void _buildSegments() {
    try {
      final meta = widget.raw['metaData'];
      if (meta is! Map) {
        debugMsg = 'raw.metaData 없음\nkeys=${widget.raw.keys.toList()}';
        setState(() {});
        return;
      }

      final plan = meta['plan'];
      if (plan is! Map) {
        debugMsg = 'metaData.plan 없음\nmeta keys=${meta.keys.toList()}';
        setState(() {});
        return;
      }

      final itineraries = plan['itineraries'];
      if (itineraries is! List || itineraries.isEmpty) {
        debugMsg = 'plan.itineraries 없음/비어있음\nplan keys=${plan.keys.toList()}';
        setState(() {});
        return;
      }

      final first = itineraries.first;
      if (first is! Map) {
        debugMsg = 'itineraries.first가 Map이 아님';
        setState(() {});
        return;
      }

      final legs = first['legs'];
      if (legs is! List || legs.isEmpty) {
        debugMsg = 'itinerary.legs 없음/비어있음\nitinerary keys=${first.keys.toList()}';
        setState(() {});
        return;
      }

      final segs = buildSegmentsFromLegs(legs);
      if (segs.isEmpty) {
        debugMsg = 'segments 0개 (linestring 없음?)\nlegs count=${legs.length}';
        setState(() {});
        return;
      }

      segments = segs;
      summary = buildSummaryFromLegs(legs);

      final allPts = segments.expand((e) => e.points).toList();
      debugMsg =
      'OK: segments=${segments.length}, points=${allPts.length}\n'
          'walk=${summary.walkMin}m bus=${summary.busMin}m subway=${summary.subwayMin}m transfer=${summary.transferCount}\n'
          'first=${allPts.first}\nlast=${allPts.last}';

      setState(() {});
    } catch (e) {
      debugMsg = '예외: $e';
      setState(() {});
    }
  }

  LatLngBounds _boundsForPoints(List<LatLng> pts) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null) ? p.latitude : min(minLat, p.latitude);
      maxLat = (maxLat == null) ? p.latitude : max(maxLat, p.latitude);
      minLng = (minLng == null) ? p.longitude : min(minLng, p.longitude);
      maxLng = (maxLng == null) ? p.longitude : max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _fitToRoute() async {
    if (_mapCtrl == null || segments.isEmpty) return;
    final allPts = segments.expand((e) => e.points).toList();
    if (allPts.isEmpty) return;

    final bounds = _boundsForPoints(allPts);
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  Future<void> _focusSegment(_LegSegment seg) async {
    if (_mapCtrl == null || seg.points.isEmpty) return;

    if (seg.points.length == 1) {
      await _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(seg.points.first, 16));
      return;
    }

    final b = _boundsForPoints(seg.points);
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(b, 80));
  }

  //jgh251226-----------------------------------------S
  // ✅ bounds를 조금 넓혀서 CCTV 조회 범위를 확장
  LatLngBounds _expandBounds(LatLngBounds b, double padLat, double padLng) {
    return LatLngBounds(
      southwest: LatLng(b.southwest.latitude - padLat, b.southwest.longitude - padLng),
      northeast: LatLng(b.northeast.latitude + padLat, b.northeast.longitude + padLng),
    );
  }

  // ✅ ITS 응답 구조가 달라도 data 리스트를 최대한 찾아 반환
  List<Map<String, dynamic>> _extractCctvDataList(dynamic root) {
    dynamic node = root;

    // 케이스1: {"response": {"data": [...]}}
    if (node is Map && node['response'] != null) node = node['response'];

    final data = (node is Map) ? node['data'] : null;
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    // 케이스2: {"data": [...]}
    if (root is Map && root['data'] is List) {
      return (root['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // 케이스3: 아예 리스트만 오는 경우
    if (root is List) {
      return root.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return const [];
  }

  // ✅ 경로 주변 CCTV 로딩 → 마커 생성
  Future<void> _loadCctvNearRoute() async {
    if (_loadingCctv) return;
    if (segments.isEmpty) return;

    if (_itsApiKey == 'YOUR_ITS_API_KEY') {
      setState(() => _cctvDebug = 'ITS apiKey를 넣어야 CCTV 조회가 됩니다.');
      return;
    }

    final allPts = segments.expand((e) => e.points).toList();
    if (allPts.isEmpty) return;

    setState(() {
      _loadingCctv = true;
      _cctvDebug = 'CCTV 조회중...';
    });

    try {
      final base = _boundsForPoints(allPts);

      // ✅ 너무 타이트하면 CCTV가 안 잡힐 수 있어서 약간 확장 (0.01 ≒ 1km 내외)
      final b = _expandBounds(base, 0.01, 0.01);

      final uri = Uri.parse('https://openapi.its.go.kr:9443/cctvInfo').replace(
        queryParameters: {
          'apiKey': _itsApiKey,
          'type': 'all',
          'cctvType': '4', // ✅ HTTPS HLS
          'minX': b.southwest.longitude.toString(),
          'maxX': b.northeast.longitude.toString(),
          'minY': b.southwest.latitude.toString(),
          'maxY': b.northeast.latitude.toString(),
          'getType': 'json',
        },
      );

      final res = await http.get(uri, headers: {'Accept': 'application/json'});

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}\n${res.body}');
      }

      final jsonMap = json.decode(res.body);
      final dataList = _extractCctvDataList(jsonMap);

      final newMarkers = <Marker>{};

      int idx = 0;
      for (final m in dataList) {
        final item = _CctvItem.fromMap(m);
        if (item == null) continue;

        final markerId = 'cctv_${idx++}_${item.coordY}_${item.coordX}';

        newMarkers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: LatLng(item.coordY, item.coordX),
            icon: _cctvIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), // ✅ CCTV 전용
            infoWindow: InfoWindow(title: item.name, snippet: item.format),
            onTap: () async {
              final fresh = await _refreshOneCctvUrl(item) ?? item;
              _openCctvPlayer(fresh);
            },
          ),
        );

      }

      setState(() {
        _cctvMarkers
          ..clear()
          ..addAll(newMarkers);

        _cctvDebug = 'CCTV ${newMarkers.length}개 표시됨';
      });
    } catch (e) {
      setState(() => _cctvDebug = 'CCTV 조회 실패: $e');
    } finally {
      setState(() => _loadingCctv = false);
    }
  }

  // ✅ CCTV 탭 → 플레이어 페이지로 이동
  void _openCctvPlayer(_CctvItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _CctvPlayerPage(item: item)),
    );
  }

  // ✅ (중요) 마커 탭 순간에 URL을 새로 받아오기 (토큰 만료/세션 만료 대응)
  Future<_CctvItem?> _refreshOneCctvUrl(_CctvItem old) async {
    // old 좌표 주변만 좁게 다시 조회해서 "최신 URL" 받기
    final b = LatLngBounds(
      southwest: LatLng(old.coordY - 0.002, old.coordX - 0.002),
      northeast: LatLng(old.coordY + 0.002, old.coordX + 0.002),
    );

    final uri = Uri.parse('https://openapi.its.go.kr:9443/cctvInfo').replace(
      queryParameters: {
        'apiKey': _itsApiKey,
        'type': 'all',
        'cctvType': '4',
        'minX': b.southwest.longitude.toString(),
        'maxX': b.northeast.longitude.toString(),
        'minY': b.southwest.latitude.toString(),
        'maxY': b.northeast.latitude.toString(),
        'getType': 'json',
      },
    );

    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) return null;

    final jsonMap = json.decode(res.body);
    final dataList = _extractCctvDataList(jsonMap);

    // 좌표가 가장 가까운 CCTV를 선택(이름이 같지 않을 수 있어 좌표 기준이 안전)
    _CctvItem? best;
    double bestD = 1e18;

    for (final m in dataList) {
      final it = _CctvItem.fromMap(m);
      if (it == null) continue;
      final dx = it.coordX - old.coordX;
      final dy = it.coordY - old.coordY;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = it;
      }
    }

    return best;
  }


  //jgh251226-----------------------------------------E


  @override
  Widget build(BuildContext context) {
    final allPoints = segments.expand((e) => e.points).toList();

    final polylines = <Polyline>{};
    for (final seg in segments) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('seg_${seg.index}_${seg.mode}'),
          points: seg.points,
          width: seg.mode == _LegMode.walk ? 5 : 7,
          color: seg.color,
          patterns: seg.mode == _LegMode.walk
              ? <PatternItem>[PatternItem.dash(18), PatternItem.gap(10)]
              : const <PatternItem>[],
        ),
      );
    }

    //251229
    final markers = <Marker>{};
    if (allPoints.isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: allPoints.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // ✅ 출발: 초록
          infoWindow: const InfoWindow(title: '출발'),
        ),
      );

      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: allPoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // ✅ 도착: 빨강
          infoWindow: const InfoWindow(title: '도착'),
        ),
      );
    }
    markers.addAll(_cctvMarkers);
    //251229

    return PutterScaffold(
      currentIndex: 0,
      body: Scaffold(
        appBar: AppBar(
          title: const Text('경로 보기'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              tooltip: '경로에 맞추기',
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _fitToRoute,
            ),
          ],
        ),

        // ✅ 부모 스크롤은 기본 ON, 지도 조작 중에만 OFF
        body: SingleChildScrollView(
          physics: _isMapInteracting
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ 지도 + 요약바를 겹치기 위해 Stack 사용
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 520, // 지도를 크게 보이게
                    child: Stack(
                      children: [
                        Positioned.fill(
                          // ✅ 지도 터치 시작하면 부모 스크롤 OFF
                          child: Listener(
                            onPointerDown: (_) => setState(() => _isMapInteracting = true),
                            onPointerUp: (_) => setState(() => _isMapInteracting = false),
                            onPointerCancel: (_) => setState(() => _isMapInteracting = false),
                            child: allPoints.isEmpty
                                ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '지도 표시 불가\n$debugMsg',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                                : GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: allPoints.first,
                                zoom: 13,
                              ),
                              polylines: polylines,
                              markers: markers,
                              onMapCreated: (c) async {
                                _mapCtrl = c;
                                await _fitToRoute();
                                await _loadCctvNearRoute(); // ✅ 추가 //jgh251226
                              },

                              // ✅ 지도 제스처 ON (이동/줌/회전/기울기)
                              scrollGesturesEnabled: true,
                              zoomGesturesEnabled: true,
                              rotateGesturesEnabled: true,
                              tiltGesturesEnabled: true,

                              // ✅ + / - 버튼 (Android에서 표시)
                              zoomControlsEnabled: true,

                              myLocationButtonEnabled: false,
                            ),
                          ),
                        ),

                        // ✅ 요약바를 지도 위에 “플로팅 카드”로 올리기
                        Positioned(
                          left: 10,
                          right: 10,
                          top: 55,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _cctvDebug,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ✅ 아래 구간 리스트 (페이지 스크롤로 내려서 보는 방식)
              _LegListPage(
                segments: segments,
                onTapSegment: (seg) => _focusSegment(seg),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- UI: 요약/리스트 -------------------- */

class _FloatingSummary extends StatelessWidget {
  final _LegSummary summary;
  const _FloatingSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('도보 ${summary.walkMin}분', Icons.directions_walk),
          chip('버스 ${summary.busMin}분', Icons.directions_bus),
          chip('지하철 ${summary.subwayMin}분', Icons.subway),
          chip('환승 ${summary.transferCount}회', Icons.sync_alt),
        ],
      ),
    );
  }
}

/// ✅ 페이지 스크롤 방식용 리스트(리스트 자체는 스크롤 안 함)
class _LegListPage extends StatelessWidget {
  final List<_LegSegment> segments;
  final void Function(_LegSegment seg) onTapSegment;
  const _LegListPage({required this.segments, required this.onTapSegment});

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    IconData iconFor(_LegMode m) {
      switch (m) {
        case _LegMode.walk:
          return Icons.directions_walk;
        case _LegMode.bus:
          return Icons.directions_bus;
        case _LegMode.subway:
          return Icons.subway;
        case _LegMode.other:
          return Icons.route;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: segments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final s = segments[i];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTapSegment(s),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.color.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 42,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(iconFor(s.mode), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${s.minutes}분', style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* -------------------- Data model for segments -------------------- */

enum _LegMode { walk, bus, subway, other }

class _LegSegment {
  final int index;
  final _LegMode mode;
  final List<LatLng> points;
  final int minutes;
  final String label;
  final Color color;

  const _LegSegment({
    required this.index,
    required this.mode,
    required this.points,
    required this.minutes,
    required this.label,
    required this.color,
  });
}

class _LegSummary {
  final int walkMin;
  final int busMin;
  final int subwayMin;
  final int transferCount;

  const _LegSummary({
    required this.walkMin,
    required this.busMin,
    required this.subwayMin,
    required this.transferCount,
  });

  const _LegSummary.empty()
      : walkMin = 0,
        busMin = 0,
        subwayMin = 0,
        transferCount = 0;
}

/* -------------------- Parse helpers -------------------- */

List<LatLng> parseLineString(String s) {
  return s
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .map((pair) {
    final parts = pair.split(',');
    final lon = double.tryParse(parts[0]) ?? 0;
    final lat = double.tryParse(parts[1]) ?? 0;
    return LatLng(lat, lon);
  })
      .toList();
}

int _secToMin(dynamic v) {
  final sec = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
  return (sec / 60).round();
}

_LegMode _modeFromLeg(Map leg) {
  final m = (leg['mode'] ?? '').toString().toUpperCase();
  if (m == 'WALK') return _LegMode.walk;
  if (m == 'BUS') return _LegMode.bus;
  if (m == 'SUBWAY') return _LegMode.subway;
  return _LegMode.other;
}

Color _colorFromLeg(Map leg, _LegMode mode) {
  String? rc = leg['routeColor']?.toString();
  if (rc != null && rc.isNotEmpty) {
    rc = rc.replaceAll('#', '');
    if (rc.length == 6) {
      final v = int.tryParse(rc, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
  }

  switch (mode) {
    case _LegMode.walk:
      return Colors.grey.shade700;
    case _LegMode.bus:
      return Colors.blue;
    case _LegMode.subway:
      return Colors.purple;
    case _LegMode.other:
      return Colors.black;
  }
}

String _labelFromLeg(Map leg, _LegMode mode) {
  final startName = (leg['start'] is Map) ? (leg['start']['name'] ?? '') : '';
  final endName = (leg['end'] is Map) ? (leg['end']['name'] ?? '') : '';
  final route = (leg['route'] ?? leg['routeName'] ?? '').toString();

  String modeK;
  switch (mode) {
    case _LegMode.walk:
      modeK = '도보';
      break;
    case _LegMode.bus:
      modeK = '버스';
      break;
    case _LegMode.subway:
      modeK = '지하철';
      break;
    case _LegMode.other:
      modeK = '이동';
      break;
  }

  final mid = route.isNotEmpty ? ' ($route)' : '';
  final se = (startName.toString().isNotEmpty || endName.toString().isNotEmpty)
      ? ' · $startName → $endName'
      : '';
  return '$modeK$mid$se';
}

List<LatLng> _pointsFromLeg(Map leg) {
  // 1) passShape.linestring
  final passShape = leg['passShape'];
  final passLs = (passShape is Map) ? passShape['linestring'] : null;
  if (passLs is String && passLs.isNotEmpty) {
    return parseLineString(passLs);
  }

  // 2) WALK steps[].linestring
  final mode = (leg['mode'] ?? '').toString().toUpperCase();
  if (mode == 'WALK' && leg['steps'] is List) {
    final pts = <LatLng>[];
    for (final step in (leg['steps'] as List)) {
      if (step is! Map) continue;
      final ls = step['linestring'];
      if (ls is String && ls.isNotEmpty) pts.addAll(parseLineString(ls));
    }
    return pts;
  }

  return const [];
}

List<_LegSegment> buildSegmentsFromLegs(List legs) {
  final segments = <_LegSegment>[];

  int idx = 0;
  for (final leg in legs) {
    if (leg is! Map) continue;

    final mode = _modeFromLeg(leg);
    final pts = _pointsFromLeg(leg);
    if (pts.isEmpty) continue;

    // 연속 중복 제거(구간별)
    final dedup = <LatLng>[];
    LatLng? prev;
    for (final p in pts) {
      if (prev == null || prev.latitude != p.latitude || prev.longitude != p.longitude) {
        dedup.add(p);
      }
      prev = p;
    }

    final minutes = _secToMin(leg['sectionTime']);
    final color = _colorFromLeg(leg, mode);
    final label = _labelFromLeg(leg, mode);

    segments.add(
      _LegSegment(
        index: idx++,
        mode: mode,
        points: dedup,
        minutes: minutes,
        label: label,
        color: color,
      ),
    );
  }

  return segments;
}

_LegSummary buildSummaryFromLegs(List legs) {
  int walk = 0, bus = 0, subway = 0;
  for (final leg in legs) {
    if (leg is! Map) continue;
    final mode = (leg['mode'] ?? '').toString().toUpperCase();
    final min = _secToMin(leg['sectionTime']);
    if (mode == 'WALK') walk += min;
    if (mode == 'BUS') bus += min;
    if (mode == 'SUBWAY') subway += min;
  }

  int transitLegs = 0;
  for (final leg in legs) {
    if (leg is! Map) continue;
    final mode = (leg['mode'] ?? '').toString().toUpperCase();
    if (mode == 'BUS' || mode == 'SUBWAY') transitLegs++;
  }
  final transfers = max(0, transitLegs - 1);

  return _LegSummary(
    walkMin: walk,
    busMin: bus,
    subwayMin: subway,
    transferCount: transfers,
  );
}
class _CctvItem {
  final String name;
  final String url;
  final String format; // HLS / mp4 / jpg 등
  final double coordX;
  final double coordY;

  _CctvItem({
    required this.name,
    required this.url,
    required this.format,
    required this.coordX,
    required this.coordY,
  });

  static _CctvItem? fromMap(Map<String, dynamic> m) {
    String s(dynamic v) => (v ?? '').toString().trim().replaceAll(';', '');
    double d(dynamic v) => double.tryParse(s(v)) ?? 0;

    final url = s(m['cctvurl'] ?? m['cctvUrl']);
    if (url.isEmpty) return null;

    final name = s(m['cctvname'] ?? m['cctvName'] ?? 'CCTV');
    final format = s(m['cctvformat'] ?? m['cctvFormat'] ?? '');
    final x = d(m['coordx'] ?? m['coordX']);
    final y = d(m['coordy'] ?? m['coordY']);
    if (x == 0 || y == 0) return null;

    return _CctvItem(name: name, url: url, format: format, coordX: x, coordY: y);
  }
}

class _CctvPlayerPage extends StatefulWidget {
  final _CctvItem item;
  const _CctvPlayerPage({super.key, required this.item});

  @override
  State<_CctvPlayerPage> createState() => _CctvPlayerPageState();
}

class _CctvPlayerPageState extends State<_CctvPlayerPage> {
  VideoPlayerController? _ctrl;
  bool _useWebView = false;
  String _msg = 'loading...';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1) 먼저 video_player로 시도
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.item.url),
        httpHeaders: {
          // 일부 CCTV 서버는 UA/Referer 없으면 막는 경우가 있어 넣어둠
          'User-Agent': 'Mozilla/5.0',
          'Accept': '*/*',
          'Referer': 'https://cctvsec.ktict.co.kr/',
        },
      );

      await c.initialize();
      await c.setLooping(true);
      await c.play();

      if (!mounted) return;
      setState(() {
        _ctrl = c;
        _useWebView = false;
        _msg = 'OK';
      });
      return;
    } catch (e) {
      // 2) 실패하면 WebView로 fallback
      if (!mounted) return;
      setState(() {
        _useWebView = true;
        _msg = 'WebView로 재생 중...'; // ✅ reloading... 덮어쓰기
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;

    return PutterScaffold(
      currentIndex: 0, // ✅ 홈 탭이 선택된 상태로(원하면 다른 값)
      body: Scaffold(
        appBar: AppBar(title: Text(widget.item.name)),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Builder(
                  builder: (context) {
                    final w = MediaQuery.sizeOf(context).width;
                    final h = w * 9 / 16;

                    return SizedBox(
                      width: double.infinity,
                      height: h,
                      child: _useWebView
                          ? WebViewWidget(
                        controller: WebViewController()
                          ..setJavaScriptMode(JavaScriptMode.unrestricted)
                          ..loadRequest(Uri.parse(widget.item.url)),
                      )
                          : (c != null && c.value.isInitialized)
                          ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: c.value.size.width,
                          height: c.value.size.height,
                          child: VideoPlayer(c),
                        ),
                      )
                          : Center(child: Text(_msg)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: (_useWebView || c == null)
                        ? null
                        : () => c.value.isPlaying ? c.pause() : c.play(),
                    child: Text((!_useWebView && c != null && c.value.isPlaying) ? '일시정지' : '재생'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () async {
                      final old = _ctrl;
                      _ctrl = null;
                      if (mounted) setState(() => _msg = 'reloading...');
                      await old?.dispose();
                      if (mounted) setState(() => _useWebView = false);
                      await _init();
                    },
                    child: const Text('새로고침'),
                  ),
                ],
              ),
              if (_useWebView) ...[
                const SizedBox(height: 8),
                Text(_msg, style: const TextStyle(fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }

}


