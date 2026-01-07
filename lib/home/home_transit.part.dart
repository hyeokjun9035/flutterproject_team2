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

// TransitCardState 교체용 (필요 import: dart:async, dart:convert, material, shared_preferences)

class TransitCardLegUiStep {
  const TransitCardLegUiStep(this.icon, this.label);
  final IconData icon;
  final String label;
}

class TransitCardBusLegInfo {
  const TransitCardBusLegInfo({
    required this.routeNo,
    required this.lat,
    required this.lon,
    required this.rawRoute,
  });

  final String routeNo;
  final double lat;
  final double lon;
  final String rawRoute;
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
  // RAW helpers
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

  String _prettyJson(Object? v) {
    try {
      return const JsonEncoder.withIndent('  ').convert(v);
    } catch (_) {
      return v.toString();
    }
  }

  void _debugDumpItineraryLegs(TransitVariant v) {
    final legs = _legsForVariant(v);
    debugPrint('[TMAP] v=$v legs=${legs.length}');
    debugPrint(_prettyJson(legs));
  }

  String _rawRouteStringFromLeg(Map<String, dynamic> leg) {
    return (leg['route'] ?? leg['routeName'] ?? leg['lineName'] ?? '').toString();
  }

  double? _toDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v');


  String _normRouteNo(String s) => s
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('번', '')
      .toUpperCase()
      .replaceAll(RegExp(r'[^0-9A-Z가-힣-]'), '');

  String? extractRouteToken(String s) {
    final cleaned = s.replaceAll(RegExp(r'\s+'), '').replaceAll('번', '');

    // "간선:402", "마을:종로09"
    final m1 = RegExp(r'[:：]([0-9A-Za-z가-힣-]+)').firstMatch(cleaned);
    final t1 = m1?.group(1);
    if (t1 != null && RegExp(r'\d').hasMatch(t1)) return t1;

    // "M6450", "1400-1", "종로09", "간선402"(콜론이 없는 경우도 방어)
    final m2 = RegExp(r'([0-9A-Za-z가-힣-]*\d[0-9A-Za-z가-힣-]*)').firstMatch(cleaned);
    return m2?.group(1);
  }

  bool _isVillageBusRoute(String rawRoute, String routeNo) {
    final r = rawRoute.replaceAll(RegExp(r'\s+'), '');

    // ✅ raw에 "마을"이 있으면 무조건 마을버스
    if (r.contains('마을')) return true;

    // ✅ raw에 "간선/지선/광역/급행/순환/직행/좌석/공항" 같은 타입이 있으면 마을버스 아님
    if (RegExp(r'(간선|지선|광역|급행|순환|직행|좌석|공항)').hasMatch(r)) return false;

    // ✅ 타입이 명시되지 않은데 노선번호에 한글이 섞이면(종로09 등) 마을버스 취급
    if (RegExp(r'[가-힣]').hasMatch(routeNo)) return true;

    return false;
  }

  bool _hasBusLeg(TransitVariant v) {
    final legs = _legsForVariant(v);
    return legs.any((leg) => (leg['mode'] ?? '').toString().toUpperCase() == 'BUS');
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

      // ✅ 마을버스면 폴링 대상 제외
      if (_isVillageBusRoute(rawRoute, routeNo)) continue;

      final start = (leg['start'] is Map)
          ? Map<String, dynamic>.from(leg['start'] as Map)
          : <String, dynamic>{};

      final lat = _toDouble(start['lat'] ?? start['startY'] ?? start['y']);
      final lon = _toDouble(start['lon'] ?? start['lng'] ?? start['startX'] ?? start['x']);

      if (lat == null || lon == null) continue;

      return _BusLegInfo(routeNo: routeNo, lat: lat, lon: lon, rawRoute: rawRoute);
    }

    return null;
  }

  // ----------------------------
  // prefs
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

  // ----------------------------
  // Bus stop cache + arrival
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

    final stops = await widget.busArrivalService.findNearbyStops(
        lat: lat,
        lon: lon,
        maxStops: 20,
    );

    debugPrint('[BUS] candidates=${stops.length} route=$routeNo '
        'near=(${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}) '
        '=> ${stops.map((s) => "${s.name}/${s.cityCode}/${s.nodeId}").join(" | ")}');

    // ✅ "routeNo가 실제로 뜨는 정류장"을 찾는다 (최대 8개)
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

    final lat = info?.lat ?? widget.startLat;
    final lon = info?.lon ?? widget.startLon;

    debugPrint('[BUS] fetch v=$v info=${info != null} rawRoute=${info?.rawRoute} '
        'lat=${lat.toStringAsFixed(6)} lon=${lon.toStringAsFixed(6)}');

    if (lat == 0.0 || lon == 0.0) return null;

    // ✅ routeNo: raw에서 우선, 없으면 summary 텍스트에서 extractRouteToken으로 뽑기
    final s = widget.data.summaryOf(v);
    final fallbackToken =
        extractRouteToken(s.firstArrivalText) ?? extractRouteToken(s.secondArrivalText);

    final routeNo = info?.routeNo ?? _normRouteNo(fallbackToken ?? '');

    debugPrint('[BUS] routeNo=$routeNo fallbackToken=$fallbackToken');

    if (routeNo.isEmpty) return null;

    final stop = await _ensureStopForRoute(lat: lat, lon: lon, routeNo: routeNo);
    if (stop == null) {
      debugPrint('[BUS] stop not found for route=$routeNo');
      return null;
    }

    return widget.busArrivalService.fetchNextArrivalText(
      cityCode: stop.cityCode,
      nodeId: stop.nodeId,
      routeNo: routeNo,
    );
  }

  void _refreshRealtimeNow() {
    final hasBus = _hasBusLeg(_selected);
    final hasVillage = _hasVillageBusLeg(_selected);
    final shouldPoll = _shouldPollBus(_selected);

    debugPrint('[BUS] refresh v=$_selected hasBus=$hasBus hasVillage=$hasVillage shouldPoll=$shouldPoll');

    if (!shouldPoll) {
      if (mounted) {
        setState(() {
          _busFuture = Future.value(null);
        });
      }
      return;
    }

    if (_liveInFlight) return;
    _liveInFlight = true;

    final busFut = _fetchBusArrivalForVariant(_selected).catchError((_) => null);

    if (mounted) {
      setState(() {
        _busFuture = busFut;
      });
    }

    busFut.then((_) {
      _liveUpdatedAt = DateTime.now();
    }).whenComplete(() {
      _liveInFlight = false;
      if (mounted) setState(() {});
    });
  }

  void _startLivePolling() {
    _liveTimer?.cancel();

    if (!_shouldPollBus(_selected)) {
      setState(() {
        _busFuture = null;
        _liveUpdatedAt = null;
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRealtimeNow());
    _liveTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshRealtimeNow());
  }

  void _resetLivePolling() {
    _invalidateStopCache();
    _startLivePolling();
  }

  // ----------------------------
  // lifecycle
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
  // UI helpers (leg flow)
  // ----------------------------
  String _hhmmss(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  List<TransitCardLegUiStep> _buildLegSteps(TransitVariant v) {
    final legs = _legsForVariant(v);

    IconData iconFromMode(String modeUp) {
      switch (modeUp) {
        case 'BUS':
          return Icons.directions_bus;
        case 'SUBWAY':
        case 'METRO':
          return Icons.subway;
        case 'TRAIN':
          return Icons.train;
        case 'WALK':
          return Icons.directions_walk;
        case 'TRANSFER':
          return Icons.swap_horiz;
        default:
          return Icons.more_horiz;
      }
    }

    String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

    String? _legMinutes(Map<String, dynamic> leg) {
      // ✅ TMAP sectionTime은 "초"로 내려오는 케이스가 많음
      final st = leg['sectionTime'];
      final sec = (st is num) ? st.toDouble() : double.tryParse('$st');
      if (sec != null) {
        final min = (sec / 60.0).floor(); // 55초면 0분 (너 routeview 표시랑 유사)
        return '${min}분';
      }

      // fallback (혼재 가능)
      final v = leg['duration'] ?? leg['time'];
      final n = (v is num) ? v.toDouble() : double.tryParse('$v');
      if (n != null) {
        final min = (n >= 120) ? (n / 60.0).floor() : n.floor();
        return '${min}분';
      }
      return null;
    }

    String _busTypeLabel(String rawRoute, String routeNo) {
      if (_isVillageBusRoute(rawRoute, routeNo)) return '마을버스';

      final cleaned = rawRoute.replaceAll(RegExp(r'\s+'), '');
      if (cleaned.contains('간선')) return '간선버스';
      if (cleaned.contains('지선')) return '지선버스';
      if (cleaned.contains('광역')) return '광역버스';
      if (cleaned.contains('순환')) return '순환버스';
      if (cleaned.contains('급행')) return '급행버스';
      return '버스';
    }

    String _firstNonEmpty(List<dynamic> xs) {
      for (final x in xs) {
        final s = (x ?? '').toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    String labelFromLeg(Map<String, dynamic> leg) {
      final modeUp = (leg['mode'] ?? '').toString().toUpperCase();
      final start = (leg['start'] is Map) ? Map<String, dynamic>.from(leg['start'] as Map) : const {};
      final end = (leg['end'] is Map) ? Map<String, dynamic>.from(leg['end'] as Map) : const {};

      final startName = _clean((start['name'] ?? '').toString());
      final endName = _clean((end['name'] ?? '').toString());

      if (modeUp == 'BUS') {
        final rawRoute = _rawRouteStringFromLeg(leg);
        final token = extractRouteToken(rawRoute) ?? _clean(rawRoute);
        final routeNo = _normRouteNo(token);

        final head = _busTypeLabel(rawRoute, routeNo);
        final core = token.isEmpty ? head : '$head $token';

        if (startName.isNotEmpty && endName.isNotEmpty) {
          return _clean('$core · $startName→$endName');
        }
        return core;
      }

      if (modeUp == 'SUBWAY' || modeUp == 'METRO') {
        String line = _firstNonEmpty([leg['route'], leg['lineName'], leg['routeName']]);

        // Lane에 더 자세한 route가 있으면 그걸 우선
        final lane = (leg['Lane'] is List && (leg['Lane'] as List).isNotEmpty)
            ? Map<String, dynamic>.from((leg['Lane'] as List).first as Map)
            : null;
        final laneRoute = lane?['route']?.toString().trim() ?? '';
        if (laneRoute.isNotEmpty) line = laneRoute;

        final core = line.isNotEmpty ? line : '지하철';
        if (startName.isNotEmpty && endName.isNotEmpty) {
          return _clean('$core · $startName→$endName');
        }
        return _clean(core);
      }

      if (modeUp == 'TRAIN') {
        String line = _firstNonEmpty([leg['route'], leg['lineName'], leg['routeName']]);
        final lane = (leg['Lane'] is List && (leg['Lane'] as List).isNotEmpty)
            ? Map<String, dynamic>.from((leg['Lane'] as List).first as Map)
            : null;
        final laneRoute = lane?['route']?.toString().trim() ?? '';
        if (laneRoute.isNotEmpty) line = laneRoute;

        final core = line.isNotEmpty ? line : '열차';
        if (startName.isNotEmpty && endName.isNotEmpty) {
          return _clean('$core · $startName→$endName');
        }
        return _clean(core);
      }

      if (modeUp == 'WALK') {
        final m = _legMinutes(leg);
        return m == null ? '도보' : '도보 $m';
      }

      if (modeUp == 'TRANSFER') return '환승';
      return modeUp.isEmpty ? '이동' : modeUp;
    }

    final out = <TransitCardLegUiStep>[];
    out.add(const TransitCardLegUiStep(Icons.my_location, '출발'));

    for (final leg in legs) {
      final modeUp = (leg['mode'] ?? '').toString().toUpperCase();
      if (modeUp.isEmpty) continue;

      out.add(TransitCardLegUiStep(
        iconFromMode(modeUp),
        labelFromLeg(leg),
      ));
    }

    out.add(const TransitCardLegUiStep(Icons.flag, '도착'));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget _buildFlowRow(List<TransitCardLegUiStep> steps) {
      if (steps.isEmpty) return const SizedBox.shrink();

      Widget node(TransitCardLegUiStep s) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 18, color: Colors.white),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Tooltip(
                message: s.label, // ✅ 혹시라도 화면에서 보기 불편하면 길게 눌러 풀네임
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

          // ✅ raw legs 샘플 보고 싶으면 이거 유지
          // _debugDumpItineraryLegs(v);

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
          _buildFlowRow(flowSteps),
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
              final hasVillage = _hasVillageBusLeg(_selected);

              if (!hasBus) return const SizedBox.shrink();

              // ✅ 마을버스 포함이면 고정 멘트
              if (hasVillage) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '마을버스 정보는 지원하지 않습니다',
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                );
              }

              if (_busFuture == null || snap.connectionState == ConnectionState.waiting) {
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
    required this.startLat, // ✅ 추가
    required this.startLon, // ✅ 추가
    required this.endLat,   // ✅ 추가
    required this.endLon,   // ✅ 추가
    this.onFavoritePressed,
  });

  final String title;
  final String subtitle;
  final double distanceMeters;
  final int walkMinutes;

  // ✅ 도보 길찾기용 좌표
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;

  final VoidCallback? onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '가까운 거리라 도보를 추천해요',
            style: t.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
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

          // ✅ 버튼 UI 통일
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.directions_walk, size: 15),
                label: const Text('도보로 이동'),
                onPressed: () async {
                  if (startLat == 0.0 || startLon == 0.0 || endLat == 0.0 || endLon == 0.0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('길찾기 좌표가 없습니다.')),
                    );
                    return;
                  }
                  await openWalkDirections(
                    startLat: startLat,
                    startLon: startLon,
                    endLat: endLat,
                    endLon: endLon,
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.bookmark_border, size: 15),
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
  final String routeNo;
  final double lat;
  final double lon;
  final String rawRoute;
  const _BusLegInfo({
    required this.routeNo,
    required this.lat,
    required this.lon,
    required this.rawRoute,
  });
}

double? _toDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v');

String _normRouteNo(String s) => s
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll('번', '')
    .toUpperCase()
    .replaceAll(RegExp(r'[^0-9A-Z가-힣-]'), '');

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