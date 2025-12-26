import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  GoogleMapController? _mapCtrl;

  // ✅ 지도 조작 중에는 부모 스크롤을 잠깐 막기 위한 플래그
  bool _isMapInteracting = false;

  @override
  void initState() {
    super.initState();
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

    final markers = <Marker>{};
    if (allPoints.isNotEmpty) {
      markers.add(Marker(markerId: const MarkerId('start'), position: allPoints.first));
      markers.add(Marker(markerId: const MarkerId('end'), position: allPoints.last));
    }

    return Scaffold(
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
                        top: 10,
                        child: _FloatingSummary(summary: summary),
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
