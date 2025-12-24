import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Routeview extends StatefulWidget {
  final Map<String, dynamic> raw;
  const Routeview({super.key, required this.raw});

  @override
  State<Routeview> createState() => _RouteviewState();
}

class _RouteviewState extends State<Routeview> {
  List<LatLng> routePoints = const [];
  String debugMsg = 'init...';

  @override
  void initState() {
    super.initState();
    _buildPoints();
  }

  void _buildPoints() {
    try {
      final meta = widget.raw['metaData'];
      if (meta is! Map) {
        debugMsg = 'raw.metaData 없음\nkeys=${widget.raw.keys.toList()}';
        return;
      }

      final plan = meta['plan'];
      if (plan is! Map) {
        debugMsg = 'metaData.plan 없음\nmeta keys=${meta.keys.toList()}';
        return;
      }

      final itineraries = plan['itineraries'];
      if (itineraries is! List || itineraries.isEmpty) {
        debugMsg =
        'plan.itineraries 없음/비어있음\nplan keys=${plan.keys.toList()}';
        return;
      }

      final first = itineraries.first;
      if (first is! Map) {
        debugMsg = 'itineraries.first가 Map이 아님';
        return;
      }

      final legs = first['legs'];
      if (legs is! List || legs.isEmpty) {
        debugMsg = 'itinerary.legs 없음/비어있음\nitinerary keys=${first.keys.toList()}';
        return;
      }

      final pts = buildRoutePointsFromLegs(legs);
      if (pts.isEmpty) {
        debugMsg = 'routePoints가 0개 (linestring 없음?)\nlegs count=${legs.length}';
        return;
      }

      routePoints = pts;
      debugMsg = 'OK: points=${routePoints.length}\nfirst=${routePoints.first}\nlast=${routePoints.last}';
    } catch (e) {
      debugMsg = '예외: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 무조건 뭔가 보이게: 상단에 디버그 텍스트
    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 보기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 디버그 영역
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black12,
            child: Text(
              debugMsg,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: routePoints.isEmpty
                ? const Center(child: Text('지도 표시 불가 (위 디버그 메시지 확인)'))
                : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: routePoints.first,
                zoom: 13,
              ),
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: routePoints,
                  width: 6,
                ),
              },
              markers: {
                Marker(
                  markerId: const MarkerId('start'),
                  position: routePoints.first,
                ),
                Marker(
                  markerId: const MarkerId('end'),
                  position: routePoints.last,
                ),
              },
              onMapCreated: (_) {
                // 지도 생성 콜백 확인용
                // ignore: avoid_print
                print('GoogleMap created!');
              },
            ),
          ),
        ],
      ),
    );
  }
}

List<LatLng> parseLineString(String s) {
  return s
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .map((pair) {
    final parts = pair.split(',');
    final lon = double.parse(parts[0]);
    final lat = double.parse(parts[1]);
    return LatLng(lat, lon);
  })
      .toList();
}

List<LatLng> buildRoutePointsFromLegs(List legs) {
  final points = <LatLng>[];

  for (final leg in legs) {
    if (leg is! Map) continue;

    // 1) passShape.linestring
    final passShape = leg['passShape'];
    final passLs = (passShape is Map) ? passShape['linestring'] : null;
    if (passLs is String && passLs.isNotEmpty) {
      points.addAll(parseLineString(passLs));
      continue;
    }

    // 2) WALK steps[].linestring
    if (leg['mode'] == 'WALK' && leg['steps'] is List) {
      for (final step in (leg['steps'] as List)) {
        if (step is! Map) continue;
        final ls = step['linestring'];
        if (ls is String && ls.isNotEmpty) {
          points.addAll(parseLineString(ls));
        }
      }
    }
  }

  // 연속 중복 제거
  final dedup = <LatLng>[];
  LatLng? prev;
  for (final p in points) {
    if (prev == null ||
        prev.latitude != p.latitude ||
        prev.longitude != p.longitude) {
      dedup.add(p);
    }
    prev = p;
  }
  return dedup;
}
