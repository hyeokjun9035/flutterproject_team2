part of 'home_page.dart';

class _TransitCard extends StatefulWidget {
  const _TransitCard({
    required this.data,
    required this.busArrivalService,
    required this.favoriteId,
    required this.startLat,
    required this.startLon,
    this.onFavoritePressed,
  });

  final TransitRouteResult data;
  final VoidCallback? onFavoritePressed;
  final BusArrivalService busArrivalService;
  final String? favoriteId;
  final double startLat;
  final double startLon;
  @override
  State<_TransitCard> createState() => _TransitCardState();
}

class _TransitCardState extends State<_TransitCard> {
  TransitVariant _selected = TransitVariant.fastest;

  String _variantKey(String favId) => 'transit_variant_v1_$favId';

  // ✅ 1분 폴링
  Timer? _liveTimer;
  bool _liveInFlight = false;

  Future<String?>? _busFuture;
  DateTime? _liveUpdatedAt;

  final Map<String, TagoStop> _stopCache = {};
  final Map<String, DateTime> _stopCacheAt = {};

  // ----------------------------
  // RAW legs helpers
  // ----------------------------

  List<Map<String, dynamic>> _legsForVariant(TransitVariant v) {
    final raw = widget.data.raw;
    if (raw.isEmpty) return const [];

    final meta = (raw['metaData'] ?? raw['meta']) as Map? ?? {};
    final plan = (meta['plan'] ?? {}) as Map? ?? {};
    final itins = (plan['itineraries'] ?? []) as List? ?? const [];
    if (itins.isEmpty) return const [];

    final idx = widget.data.indexOf(v);
    if (idx < 0 || idx >= itins.length) return const [];

    final it = Map<String, dynamic>.from(itins[idx] as Map);
    final legs = (it['legs'] ?? const []) as List? ?? const [];

    return legs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _rawRouteStringFromLeg(Map<String, dynamic> leg) {
    return (leg['route'] ?? leg['routeName'] ?? leg['lineName'] ?? '').toString();
  }

  double? _toDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v');

  String? extractRouteToken(String s) {
    final cleaned = s.replaceAll(RegExp(r'\s+'), '').replaceAll('번', '');

    // 1) "간선:402", "마을:종로09" 처럼 콜론 뒤
    final m1 = RegExp(r'[:：]([0-9A-Za-z가-힣-]+)').firstMatch(cleaned);
    final t1 = m1?.group(1);
    if (t1 != null && RegExp(r'\d').hasMatch(t1)) return t1;

    // 2) 숫자 포함 토큰
    final m2 = RegExp(r'([0-9A-Za-z가-힣-]*\d[0-9A-Za-z가-힣-]*)').firstMatch(cleaned);
    return m2?.group(1);
  }

  String _normRouteNo(String s) => s
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('번', '')
      .toUpperCase()
      .replaceAll(RegExp(r'[^0-9A-Z가-힣-]'), '');

  bool _isVillageBusRoute(String rawRoute, String routeNo) {
    if (rawRoute.contains('마을')) return true;
    if (RegExp(r'[가-힣]').hasMatch(routeNo)) return true;
    return false;
  }

  bool _hasBusLeg(TransitVariant v) {
    final legs = _legsForVariant(v);
    for (final leg in legs) {
      final mode = (leg['mode'] ?? '').toString().toUpperCase();
      if (mode == 'BUS') return true;
    }
    return false;
  }

  bool _hasVillageBusLeg(TransitVariant v) {
    final legs = _legsForVariant(v);
    for (final leg in legs) {
      final mode = (leg['mode'] ?? '').toString().toUpperCase();
      if (mode != 'BUS') continue;

      final rawRoute = _rawRouteStringFromLeg(leg);
      final token = extractRouteToken(rawRoute) ?? rawRoute;
      final routeNo = _normRouteNo(token);

      if (_isVillageBusRoute(rawRoute, routeNo)) return true;
    }
    return false;
  }

  bool _shouldPollBus(TransitVariant v) {
    if (!_hasBusLeg(v)) return false;
    // ✅ 마을버스가 섞인 루트면 폴링 자체를 안 함(요구사항)
    if (_hasVillageBusLeg(v)) return false;
    return true;
  }

  _BusLegInfo? _firstPollableBusLegInfoFromRaw(TransitVariant v) {
    final legs = _legsForVariant(v);

    for (final leg in legs) {
      final mode = (leg['mode'] ?? '').toString().toUpperCase();
      if (mode != 'BUS') continue;

      final rawRoute = _rawRouteStringFromLeg(leg);
      final token = extractRouteToken(rawRoute);
      if (token == null) continue;

      final routeNo = _normRouteNo(token);
      if (routeNo.isEmpty) continue;

      if (_isVillageBusRoute(rawRoute, routeNo)) continue;

      final start = (leg['start'] is Map) ? Map<String, dynamic>.from(leg['start'] as Map) : <String, dynamic>{};

      final lat = _toDouble(start['lat'] ?? start['startY'] ?? start['y']);
      final lon = _toDouble(start['lon'] ?? start['lng'] ?? start['startX'] ?? start['x']);
      if (lat == null || lon == null) continue;

      return _BusLegInfo(routeNo: routeNo, lat: lat, lon: lon);
    }

    return null;
  }

  // ----------------------------
  // Variant persistence
  // ----------------------------

  Future<void> _loadVariant() async {
    final favId = widget.favoriteId;
    if (favId == null || favId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_variantKey(favId));

    final v = TransitVariant.values.firstWhere(
          (e) => e.name == saved,
      orElse: () => TransitVariant.fastest,
    );

    if (!mounted) return;
    setState(() => _selected = v);
  }

  Future<void> _saveVariant(TransitVariant v) async {
    final favId = widget.favoriteId;
    if (favId == null || favId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_variantKey(favId), v.name);
  }

  void _debugDumpItineraryLegs(TransitVariant v) {
    final legs = _legsForVariant(v);
    debugPrint('[TMAP] v=$v legs=${legs.length}');
    debugPrint(const JsonEncoder.withIndent('  ').convert(legs));
  }

  // ----------------------------
  // Realtime bus polling
  // ----------------------------

  String _stopKey(double lat, double lon, String routeNo) =>
      '${_normRouteNo(routeNo)}@${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';

  void _invalidateStopCache() {
    _stopCache.clear();
    _stopCacheAt.clear();
  }

  Future<TagoStop?> _ensureStopForRoute({
    required double lat,
    required double lon,
    required String routeNo,
  }) async {
    final key = _stopKey(lat, lon, routeNo);
    final now = DateTime.now();

    final cached = _stopCache[key];
    final cachedAt = _stopCacheAt[key];
    if (cached != null && cachedAt != null && now.difference(cachedAt).inMinutes < 10) {
      return cached;
    }

    final stops = await widget.busArrivalService.findNearbyStops(lat: lat, lon: lon, maxStops: 8);

    for (final st in stops) {
      final t = await widget.busArrivalService.fetchNextArrivalText(
        cityCode: st.cityCode,
        nodeId: st.nodeId,
        routeNo: routeNo,
      );
      if (t != null && t.trim().isNotEmpty) {
        _stopCache[key] = st;
        _stopCacheAt[key] = now;
        return st;
      }
    }
    return null;
  }

  Future<String?> _fetchBusArrivalForVariant(TransitVariant v) async {
    if (!_shouldPollBus(v)) return null;

    final info = _firstPollableBusLegInfoFromRaw(v);
    if (info == null) return null;

    final lat = info.lat;
    final lon = info.lon;
    final routeNo = info.routeNo;

    final stop = await _ensureStopForRoute(lat: lat, lon: lon, routeNo: routeNo);
    if (stop == null) return null;

    return widget.busArrivalService.fetchNextArrivalText(
      cityCode: stop.cityCode,
      nodeId: stop.nodeId,
      routeNo: routeNo,
    );
  }

  void _startLivePolling() {
    _liveTimer?.cancel();

    if (!_shouldPollBus(_selected)) {
      setState(() => _busFuture = Future.value(null));
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRealtimeNow());
    _liveTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshRealtimeNow());
  }

  void _resetLivePolling() {
    _invalidateStopCache();
    _startLivePolling();
  }

  void _refreshRealtimeNow() {
    if (!_shouldPollBus(_selected)) {
      if (mounted) setState(() => _busFuture = Future.value(null));
      return;
    }

    if (_liveInFlight) return;
    _liveInFlight = true;

    final busFut = _fetchBusArrivalForVariant(_selected).catchError((_) => null);

    if (mounted) setState(() => _busFuture = busFut);

    busFut.then((_) => _liveUpdatedAt = DateTime.now()).whenComplete(() {
      _liveInFlight = false;
      if (mounted) setState(() {});
    });
  }

  // ----------------------------
  // UI building: steps from RAW legs
  // ----------------------------

  String _cleanLabel(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _firstNonEmpty(List<dynamic> xs) {
    for (final x in xs) {
      final s = (x ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _legMinutesText(Map<String, dynamic> leg) {
    final st = leg['sectionTime'];
    if (st is num) {
      final min = (st.toDouble() / 60.0).ceil();
      return '${min}분';
    }

    final v = leg['duration'] ?? leg['time'];
    if (v is num) {
      final n = v.toDouble();
      final min = (n >= 120) ? (n / 60.0).ceil() : n.ceil();
      return '${min}분';
    }

    return '';
  }

  IconData _iconFromMode(String modeUp) {
    if (modeUp == 'BUS') return Icons.directions_bus;
    if (modeUp == 'SUBWAY' || modeUp == 'METRO') return Icons.subway;
    if (modeUp == 'WALK') return Icons.directions_walk;
    if (modeUp == 'TRANSFER') return Icons.swap_horiz;
    if (modeUp == 'TRAIN') return Icons.train;
    return Icons.more_horiz;
  }

  String _labelFromLeg(Map<String, dynamic> leg) {
    final modeUp = (leg['mode'] ?? '').toString().toUpperCase();
    final start = (leg['start'] is Map) ? Map<String, dynamic>.from(leg['start'] as Map) : const {};
    final end = (leg['end'] is Map) ? Map<String, dynamic>.from(leg['end'] as Map) : const {};

    final startName = _cleanLabel((start['name'] ?? '').toString());
    final endName = _cleanLabel((end['name'] ?? '').toString());

    if (modeUp == 'BUS') {
      final rawRoute = _rawRouteStringFromLeg(leg);
      final token = extractRouteToken(rawRoute) ?? _cleanLabel(rawRoute);
      final routeNo = _normRouteNo(token);
      final isVillage = _isVillageBusRoute(rawRoute, routeNo);

      final head = isVillage ? '마을버스' : '버스';
      final core = token.isEmpty ? head : '$head $token';

      if (startName.isNotEmpty && endName.isNotEmpty) {
        return _cleanLabel('$core · $startName→$endName');
      }
      return core;
    }

    if (modeUp == 'SUBWAY' || modeUp == 'METRO') {
      final line = _firstNonEmpty([leg['route'], leg['lineName'], leg['routeName']]);
      final core = line.isNotEmpty ? line : '지하철';
      if (startName.isNotEmpty && endName.isNotEmpty) {
        return _cleanLabel('$core · $startName→$endName');
      }
      return _cleanLabel(core);
    }

    if (modeUp == 'WALK') {
      final m = _legMinutesText(leg);
      return m.isEmpty ? '도보' : '도보 $m';
    }

    if (modeUp == 'TRAIN') {
      final name = _firstNonEmpty([leg['routeName'], leg['lineName'], leg['route']]);
      final core = name.isNotEmpty ? name : '열차';
      if (startName.isNotEmpty && endName.isNotEmpty) {
        return _cleanLabel('$core · $startName→$endName');
      }
      return core;
    }

    if (modeUp == 'TRANSFER') return '환승';

    return modeUp.isEmpty ? '이동' : modeUp;
  }

  List<_LegUiStep> _buildLegSteps(TransitVariant v) {
    final legs = _legsForVariant(v);

    final out = <_LegUiStep>[];
    out.add(_LegUiStep(Icons.my_location, '출발'));

    for (final leg in legs) {
      final modeUp = (leg['mode'] ?? '').toString().toUpperCase();
      if (modeUp.isEmpty) continue;

      out.add(_LegUiStep(
        _iconFromMode(modeUp),
        _labelFromLeg(leg),
      ));
    }

    out.add(_LegUiStep(Icons.flag, '도착'));
    return out;
  }

  String _hhmmss(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ----------------------------
  // Flutter lifecycle
  // ----------------------------

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadVariant();
    _startLivePolling();
  }

  @override
  void didUpdateWidget(covariant _TransitCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.favoriteId != widget.favoriteId) {
      if (widget.favoriteId == null || widget.favoriteId!.isEmpty) {
        setState(() => _selected = TransitVariant.fastest);
        _resetLivePolling();
      } else {
        _loadVariant().then((_) => _resetLivePolling());
      }
    }

    if (oldWidget.startLat != widget.startLat || oldWidget.startLon != widget.startLon) {
      _invalidateStopCache();
    }

    if (oldWidget.data.raw != widget.data.raw) {
      _resetLivePolling();
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  // ----------------------------
  // Build
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    Widget _buildFlowRow(List<_LegUiStep> steps, TextTheme textTheme) {
      if (steps.isEmpty) return const SizedBox.shrink();

      Widget node(_LegUiStep s) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 18, color: Colors.white),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                s.label,
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: null,
                overflow: TextOverflow.visible,
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        );
      }

      Widget arrow() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white54),
      );

      final children = <Widget>[];
      for (int i = 0; i < steps.length; i++) {
        children.add(node(steps[i]));
        if (i != steps.length - 1) children.add(arrow());
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    final s = widget.data.summaryOf(_selected);
    final flowSteps = _buildLegSteps(_selected);
    final arrivalText = [s.firstArrivalText, s.secondArrivalText].where((e) => e.isNotEmpty).join(' / ');

    ChoiceChip chip(String label, TransitVariant v) {
      return ChoiceChip(
        label: Text(label),
        selected: _selected == v,
        onSelected: (_) async {
          setState(() => _selected = v);
          await _saveVariant(v);
          _debugDumpItineraryLegs(v);
          _resetLivePolling();
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: chip('최소 도보', TransitVariant.minWalk)),
              const SizedBox(width: 8),
              Expanded(child: chip('최소 시간', TransitVariant.fastest)),
              const SizedBox(width: 8),
              Expanded(child: chip('최소 환승', TransitVariant.minTransfer)),
            ],
          ),
          const SizedBox(height: 12),
          _buildFlowRow(flowSteps, textTheme),
          const SizedBox(height: 12),
          Text(
            s.summary,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            arrivalText.isEmpty ? '도착 정보 없음' : arrivalText,
            style: textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
          ),

          // ✅ 실시간 버스 도착정보
          FutureBuilder<String?>(
            future: _busFuture,
            builder: (context, snap) {
              final hasBus = _hasBusLeg(_selected);
              if (!hasBus) return const SizedBox.shrink();

              // ✅ 마을버스 포함이면: 폴링 금지 + 고정 멘트
              if (_hasVillageBusLeg(_selected)) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '마을버스 실시간 도착정보는 지원하지 않습니다',
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                );
              }

              if (_busFuture == null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '버스 도착정보 준비 중…',
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '버스 도착정보 불러오는 중…',
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                );
              }

              final live = snap.data?.trim() ?? '';
              if (live.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '버스 도착정보를 찾지 못했습니다',
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  live,
                  style: textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              );
            },
          ),

          if (_liveUpdatedAt != null && _shouldPollBus(_selected))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '업데이트: ${_hhmmss(_liveUpdatedAt!)}',
                style: textTheme.labelSmall?.copyWith(color: Colors.white54),
              ),
            ),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.route, size: 15),
                label: const Text('경로 보기'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Routeview(
                        raw: widget.data.raw,
                        initialItineraryIndex: widget.data.indexOf(_selected),
                      ),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_border, size: 15),
                label: const Text('즐겨찾기'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1976D2),
                  side: BorderSide(color: Colors.white.withOpacity(0.7)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => widget.onFavoritePressed?.call(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalkFallbackCard extends StatelessWidget {
  const _WalkFallbackCard({
    required this.title,
    required this.subtitle,
    required this.distanceMeters,
    required this.walkMinutes,
    this.onFavoritePressed,
  });

  final String title;
  final String subtitle;
  final double distanceMeters;
  final int walkMinutes;
  final VoidCallback? onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('가까운 거리라 도보를 추천해요',
              style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            '$title · 약 ${distanceMeters.toStringAsFixed(0)}m · 도보 ${walkMinutes}분',
            style: t.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: t.bodySmall?.copyWith(color: Colors.white54)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.directions_walk, size: 16),
                label: const Text('도보로 이동'),
                onPressed: () {
                  // TODO: 너 launcher 유틸에 맞춰 지도/길찾기 연결(원하면 내가 붙여줄게)
                },
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_border, size: 16),
                label: const Text('즐겨찾기'),
                onPressed: onFavoritePressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusLegInfo {
  const _BusLegInfo({required this.routeNo, required this.lat, required this.lon});
  final String routeNo;
  final double lat;
  final double lon;
}

class _LegUiStep {
  _LegUiStep(this.icon, this.label);
  final IconData icon;
  final String label;
}

class TransitTooShort implements Exception {
  TransitTooShort(this.distanceMeters, this.walkMinutes);

  final double distanceMeters;
  final int walkMinutes;

  @override
  String toString() => 'TransitTooShort(${distanceMeters.toStringAsFixed(0)}m, ${walkMinutes}min)';
}

double _deg2rad(double d) => d * 3.141592653589793 / 180.0;

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);

  final a = (sin(dLat / 2) * sin(dLat / 2)) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
          (sin(dLon / 2) * sin(dLon / 2));

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}