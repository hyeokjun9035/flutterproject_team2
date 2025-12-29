import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../cache/dashboard_cache.dart';
import '../carry/checklist_models.dart';
import '../carry/checklist_rules.dart';
import '../data/dashboard_service.dart';
import '../data/models.dart';
// 2025-12-23 jgh251223---S
import '../data/transit_service.dart';
// 2025-12-23 jgh251223---E
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 2025-12-23 jgh251223---S
// 2025-12-23 jgh251223---E
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../carry/checklist_service.dart';
import '../tmaprouteview/routeview.dart'; //jgh251224
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';
import '../headandputter/putter.dart'; //jgh251226
enum DustGrade { good, normal, bad, veryBad, unknown }


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DashboardService _service;
  // 2025-12-23 jgh251223---S
  late final TransitService _transitService;
  late final ChecklistService _checklistService;
  late Future<List<ChecklistItem>> _checkFuture;
  Future<TransitRouteResult>? _transitFuture;
  // 2025-12-23 jgh251223---E
  Future<DashboardData>? _future;

  double? _lat;
  double? _lon;
  String _locationLabel = '위치 확인 중...'; // 화면 표시용 (부평역)
  String _airAddr = '';                      // 에어코리아 검색용 (인천광역시 부평구)
  String _adminArea = '';
  DateTime? _sunrise;
  DateTime? _sunset;

  // 2025-12-23 jgh251223 상수 하드코딩---S
  // static const TransitDestination _defaultDestination = TransitDestination(
  //   name: '서울시청',
  //   lat: 37.5665,
  //   lon: 126.9780,
  // );

  static const TransitDestination _defaultDestination = TransitDestination(
    name: '강동구청',
    lat: 37.530020,
    lon: 127.123920,
  );
  // 2025-12-23 jgh251223 상수 하드코딩---E

  @override
  void initState() {
    super.initState();
    _service = DashboardService(region: 'asia-northeast3');
    _checklistService = ChecklistService();
    _checkFuture = _checklistService.fetchEnabledItems();
    // 2025-12-23 jgh251223---S
    final apiKey = dotenv.env['TMAP_API_KEY'] ??
        const String.fromEnvironment('TMAP_API_KEY', defaultValue: '');
    _transitService = TransitService(
      apiKey: apiKey,
      destination: _defaultDestination,
    );

    // 2025-12-23 jgh251223---E
    if (DashboardCache.isFresh()) {
      // ✅ 위치 라벨도 즉시 복원(화면 상단 빨리 뜸)
      _lat = DashboardCache.lat;
      _lon = DashboardCache.lon;
      _locationLabel = DashboardCache.locationLabel ?? _locationLabel;
      _airAddr = DashboardCache.airAddr ?? _airAddr;

      // ✅ 대시보드 즉시 표시
      _future = Future.value(DashboardCache.data!);

      // ✅ 뒤에서 조용히 최신화(선택: 체감 좋아짐)
      _refreshInBackground();
    } else {
      _future = _initLocationAndFetch();
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _initLocationAndFetch();
      if (!mounted) return;
      setState(() => _future = Future.value(fresh));
    } catch (_) {
      // 실패해도 캐시 화면은 이미 떠 있으니 무시
    }
  }

  bool _hasKorean(String s) => RegExp(r'[가-힣]').hasMatch(s.trim());
  bool _looksLikeOnlyNumberOrLot(String s) => RegExp(r'^[0-9\s\-]+$').hasMatch(s.trim());

  String _t(String? s) => (s ?? '').trim().replaceFirst(RegExp(r'^KR\s+'), '');

  /// ✅ 화면 표시용: "부평역/부산역/속초역" 같이 보기 좋은 이름을 고름
  String pickDisplayLabel(List<Placemark> pms) {
    // 1) 문자열들에서 "OO역" 패턴이 보이면 그걸 최우선
    final stationReg = RegExp(r'([가-힣0-9]+역)');
    for (final p in pms) {
      final blob = [
        _t(p.name),
        _t(p.thoroughfare),
        _t(p.subLocality),
        _t(p.locality),
        _t(p.subAdministrativeArea),
        _t(p.administrativeArea),
      ].where((e) => e.isNotEmpty).join(' ');

      final words = blob.split(RegExp(r'\s+'));
      for (final w0 in words) {
        final w = w0.replaceAll(RegExp(r'[^0-9A-Za-z가-힣]'), ''); // 괄호/쉼표 제거
        if (w.isEmpty || _looksLikeOnlyNumberOrLot(w)) continue;

        // ✅ "부산역" 같은 토큰만 잡고, "광역"은 제외
        if (w.endsWith('역') && w != '광역') {
          return w; // 예: 부산역, 부평역, 속초역
        }
      }
    }

    // 2) 역이 아예 없으면: 구/동/시 순으로 fallback
    for (final p in pms) {
      final candidates = <String>[
        _t(p.subAdministrativeArea), // 구가 여기로 오는 기기 있음
        _t(p.locality),
        _t(p.subLocality),
        _t(p.thoroughfare),
        _t(p.administrativeArea),
      ].where((s) => s.isNotEmpty && !_looksLikeOnlyNumberOrLot(s)).toList();

      final gu = candidates.firstWhere((s) => s.endsWith('구'), orElse: () => '');
      if (gu.isNotEmpty) return gu;

      final dong = candidates.firstWhere((s) => s.endsWith('동'), orElse: () => '');
      if (dong.isNotEmpty) return dong;

      final si = candidates.firstWhere((s) => s.endsWith('시'), orElse: () => '');
      if (si.isNotEmpty) return si;

      if (candidates.isNotEmpty) return candidates.first;
    }

    return '현재 위치';
  }

  /// ✅ 대기질 검색용 addr: "인천광역시 부평구" 같이 시/구까지만
  String pickAirAddr(List<Placemark> pms) {
    // 한글 주소가 섞인 경우 blob에서 시/구를 정규식으로 뽑기
    final reg = RegExp(
      r'(서울특별시|부산광역시|대구광역시|인천광역시|광주광역시|대전광역시|울산광역시|세종특별자치시|경기도|강원특별자치도|충청북도|충청남도|전북특별자치도|전라남도|경상북도|경상남도|제주특별자치도)\s*'
      r'([가-힣]+구|[가-힣]+시|[가-힣]+군)',
    );

    for (final p in pms) {
      final blob = [
        _t(p.name),
        _t(p.thoroughfare),
        _t(p.subLocality),
        _t(p.locality),
        _t(p.subAdministrativeArea),
        _t(p.administrativeArea),
      ].where((e) => e.isNotEmpty).join(' ');

      final m = reg.firstMatch(blob);
      if (m != null) return '${m.group(1)} ${m.group(2)}';
    }

    // 정규식 실패 시: 가능한 필드 조합으로
    for (final p in pms) {
      final admin = _t(p.administrativeArea);
      final district = _t(p.locality).isNotEmpty ? _t(p.locality) : _t(p.subAdministrativeArea);
      final addr = [admin, district].where((e) => e.isNotEmpty).join(' ');
      if (addr.isNotEmpty) return addr;
    }

    return '';
  }

  Future<DashboardData> _initLocationAndFetch({
    bool forceFreshPosition = false, // ✅ 새로고침이면 true
    bool ignoreDashboardCache = false,
    bool ignoreGeocodeCache = false,
}) async {
    // 권한/서비스 체크
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => _locationLabel = '위치 서비스 OFF');
      throw Exception('Location service disabled');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _locationLabel = '위치 권한 필요');
      throw Exception('Location permission denied');
    }

    // 위치 가져오기
    Position pos;

    if (forceFreshPosition) {
      // ✅ 새로고침: lastKnown 쓰지 말고 현재 위치 강제
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 8),
        // (옵션) Android에서 위치 갱신이 느리면 아래도 도움될 때가 있음
        // forceAndroidLocationManager: true,
      );
    } else {
      // ✅ 최초 진입: 빠르게 lastKnown 먼저
      final last = await Geolocator.getLastKnownPosition();
      pos = last ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 6),
          );
    }
    _lat = pos.latitude;
    _lon = pos.longitude;

    final nowTime = DateTime.now();
    final today = DateTime(nowTime.year, nowTime.month, nowTime.day);

    final ss = getSunriseSunset(_lat!, _lon!, nowTime.timeZoneOffset, today);

    // 역지오코딩(동 이름/구 이름)
    String adminArea = '';
    String label = '현재 위치';
    String addr = '';

    final reuseGeocode = !ignoreGeocodeCache &&
        DashboardCache.canReuseGeocode(newLat: _lat, newLon: _lon);

    if (reuseGeocode) {
      adminArea = DashboardCache.administrativeArea ?? '';
      label = DashboardCache.locationLabel ?? '현재 위치';
      addr = DashboardCache.airAddr ?? '';
    } else {
      final placemarks = await placemarkFromCoordinates(_lat!, _lon!);
      adminArea = placemarks.isNotEmpty ? (placemarks.first.administrativeArea ?? '').trim() : '';
      label = placemarks.isNotEmpty ? pickDisplayLabel(placemarks) : '현재 위치';
      addr = placemarks.isNotEmpty ? pickAirAddr(placemarks) : '';

      // ✅ 지오코딩 캐시 저장
      DashboardCache.saveGeocode(
        lat: _lat!,
        lon: _lon!,
        locationLabel: label,
        airAddr: addr,
        administrativeArea: adminArea,
      );
    }

    setState(() {
      _sunrise = ss.sunrise;
      _sunset = ss.sunset;

      _locationLabel = label;
      _airAddr = addr;
      _adminArea = adminArea;
      // _locationName = [admin, locality, _umdName].where((e) => e.isNotEmpty).join(' ');
      // 2025-12-23 jgh251223---S
      _transitFuture = _transitService.fetchRoute(
        startLat: _lat!,
        startLon: _lon!,
        startName: _locationLabel,
      );
      // 2025-12-23 jgh251223---E
    });

    // ✅ 3) Functions 호출: state 말고 지역 변수로 넘기기(안전)
    final dashboard = await _service.fetchDashboardByLatLon(
      lat: _lat!,
      lon: _lon!,
      locationName: label,
      airAddr: addr,
      administrativeArea: adminArea,
    );

    // ✅ 4) 대시보드 캐시 저장(탭 왕복 시 즉시 표시)
    DashboardCache.saveDashboard(dashboard);

    return dashboard;

  }

  void _reload() {
    setState(() {
      _future = _initLocationAndFetch(
        forceFreshPosition: true,
        ignoreDashboardCache: true,
        ignoreGeocodeCache: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1E88E5);

    return PutterScaffold(
      currentIndex: 0,
      body: Scaffold(
        body: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            // ✅ 에러 먼저 처리 (여기서 data! 쓰면 안 됨)
            if (snapshot.hasError) {
              final err = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                     const Icon(Icons.error_outline, size: 36),
                     const SizedBox(height: 12),
                     Text('데이터 로드 실패\n$err', textAlign: TextAlign.center),
                     const SizedBox(height: 12),
                     ElevatedButton(
                         onPressed: _reload,
                         child: Text('다시시도')
                     )
                    ]
                  ),
                ),
              );
            }
      
            final data = snapshot.data;
            final now = data?.now;
      
            // ✅ 로딩 조건 강화: done이 아니거나 data가 없으면 로딩
            final isLoading =
                snapshot.connectionState != ConnectionState.done || data == null;
      
            return Stack(
              children: [
                // ✅ 1) 배경 (낮/밤/구름/맑음)
                WeatherBackground(now: now, lat: _lat, lon: _lon),
      
                // ✅ 2) 비/눈 효과(PTY 기반)
                if (now != null) PrecipitationLayer(now: now),
      
                // ✅ 3) 기존 UI
                SafeArea(
                  child: RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: _TopBar(
                              locationName: _locationLabel,
                              updatedAt: data?.updatedAt,
                              onRefresh: _reload,
                            ),
                          ),
                        ),
      
                        if (!isLoading && data.alerts.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _AlertBanner(alerts: data.alerts),
                            ),
                          ),
      
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate.fixed([
                              _Card(
                                child: isLoading
                                    ? const _Skeleton(height: 120)
                                    : _WeatherHero(
                                    now: data!.now, sunrise: _sunrise, sunset: _sunset),
                              ),
                              const SizedBox(height: 12),

                              _Card(
                                child: (isLoading || data == null)
                                    ? const _Skeleton(height: 110)
                                    : FutureBuilder<List<ChecklistItem>>(
                                  future: _checkFuture,
                                  builder: (context, snap) {
                                    if (snap.connectionState == ConnectionState.waiting) {
                                      return const _Skeleton(height: 110);
                                    }
                                    if (snap.hasError) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          '체크리스트 로드 실패: ${snap.error}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                                        ),
                                      );
                                    }

                                    final all = snap.data ?? const <ChecklistItem>[];

                                    // ✅ 여기서부터는 data가 null 아님이 보장됨
                                    final list = all.where((it) => matchesRule(it, data!)).toList()
                                      ..sort((a, b) => b.priority.compareTo(a.priority));

                                    return _CarryCardFromFirestore(items: list, data: data!);
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
      
                              _Card(
                                child: isLoading
                                    ? const _Skeleton(height: 90)
                                    : _AirCard(air: data!.air),
                              ),
                              const SizedBox(height: 12),
      
                              _Card(
                                child: isLoading
                                    ? const _Skeleton(height: 90)
                                    : _HourlyStrip(items: data!.hourly),
                              ),
                              const SizedBox(height: 24),
      
                              _Card(
                                child: isLoading
                                    ? const _Skeleton(height: 120)
                                    : _WeeklyStrip(items: data!.weekly),
                              ),
                              const SizedBox(height: 12),
      
      
                              // 2025-12-23 jgh251223---S
                              _Card(
                                child: FutureBuilder<TransitRouteResult>(
                                  future: _transitFuture,
                                  builder: (context, transitSnap) {
                                    final isTransitLoading =
                                        transitSnap.connectionState != ConnectionState.done;
                                    if (isTransitLoading) {
                                      return const _Skeleton(height: 120);
                                    }
                                    if (transitSnap.hasError || !transitSnap.hasData) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          '교통 정보를 불러오지 못했습니다.\n${transitSnap.error}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      );
                                    }
                                    return _TransitCard(data: transitSnap.data!);
                                  },
                                ),
                              ),
                              // 2025-12-23 jgh251223---E
                              const SizedBox(height: 24),
      
                              // ✅ (추가) 내 주변 1km 카드 (하드코딩)
                              _Card(
                                child: const _NearbyIssuesCardHardcoded(),
                              ),
                              const SizedBox(height: 12),
      
                            ]),
                          ),
                        ),
                      ],
                    ),
                  )
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.locationName,
    required this.updatedAt,
    required this.onRefresh,
  });

  final String locationName;
  final DateTime? updatedAt;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white);
    final timeText = updatedAt == null ? '업데이트 --:--' : '업데이트 ${DateFormat('HH:mm').format(updatedAt!)}';

    return Row(
      children: [
        const Icon(Icons.place, color: Colors.white, size: 18),
        const SizedBox(width: 6),
        Text(locationName, style: textStyle?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(child: Text(timeText, style: textStyle?.copyWith(color: Colors.white70))),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: '새로고침',
        ),
      ],
    );
  }
}

class WeatherBackground extends StatelessWidget {
  const WeatherBackground({super.key, required this.now, this.lat, this.lon});
  final WeatherNow? now;
  final double? lat;
  final double? lon;

  bool _isNightBySun(double lat, double lon) {
    final nowTime = DateTime.now();

    // 오늘(로컬 날짜 기준)
    final today = DateTime(nowTime.year, nowTime.month, nowTime.day);

    final ss = getSunriseSunset(lat, lon, nowTime.timeZoneOffset, today);
    final sunrise = ss.sunrise;
    final sunset = ss.sunset;

    // 일출 전/일몰 후 => 밤
    return nowTime.isBefore(sunrise) || nowTime.isAfter(sunset);
  }

  bool _isNightFallback() {
    final h = DateTime.now().hour;
    return !(h >= 6 && h < 18);
  }

  @override
  Widget build(BuildContext context) {
    final hasCoord = lat != null && lon != null;
    final night = hasCoord ? _isNightBySun(lat!, lon!) : _isNightFallback();

    final sky = now?.sky ?? 3; // 1 맑음 / 3 구름많음 / 4 흐림(기상청 관례)
    final pty = now?.pty ?? 0;

    // 기본 베이스(낮/밤)
    List<Color> colors = night
        ? [const Color(0xFF0B1026), const Color(0xFF1A2A5A)]
        : [const Color(0xFF4FC3F7), const Color(0xFF1976D2)];

    // 구름/흐림이면 조금 회색톤 섞기
    if (sky >= 4) {
      colors = night
          ? [const Color(0xFF0B1026), const Color(0xFF2B2F3A)]
          : [const Color(0xFF90A4AE), const Color(0xFF546E7A)];
    } else if (sky == 3) {
      colors = night
          ? [const Color(0xFF0B1026), const Color(0xFF26324A)]
          : [const Color(0xFF81D4FA), const Color(0xFF455A64)];
    }

    // 비/눈이면 더 어둡고 대비 낮추기
    if (pty != 0) {
      colors = night
          ? [const Color(0xFF070A14), const Color(0xFF1B2233)]
          : [const Color(0xFF607D8B), const Color(0xFF263238)];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }
}

class PrecipitationLayer extends StatefulWidget {
  const PrecipitationLayer({super.key, required this.now});
  final WeatherNow now;

  @override
  State<PrecipitationLayer> createState() => _PrecipitationLayerState();
}

class _PrecipitationLayerState extends State<PrecipitationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rng = Random();
  late List<_Particle> _ps;

  bool get _isSnow {
    final pty = widget.now.pty ?? 0;
    return pty == 3; // 눈
  }

  bool get _isRainOrSnow {
    final pty = widget.now.pty ?? 0;
    return pty != 0;
  }

  int _countByIntensity() {
    final rn1 = widget.now.rn1 ?? 0; // mm
    if (_isSnow) return rn1 > 1.0 ? 90 : 60;
    // 비: 강수량 기준으로 입자 수 조절
    if (rn1 >= 5) return 140;
    if (rn1 >= 1) return 110;
    return 80;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(() => setState(() {}))
      ..repeat();

    _ps = List.generate(_countByIntensity(), (_) => _spawn());
  }

  _Particle _spawn() {
    return _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      v: _isSnow ? 0.15 + _rng.nextDouble() * 0.25 : 0.8 + _rng.nextDouble() * 1.6,
      drift: _isSnow ? (-0.15 + _rng.nextDouble() * 0.3) : (-0.05 + _rng.nextDouble() * 0.1),
      size: _isSnow ? (1.5 + _rng.nextDouble() * 2.5) : (0.8 + _rng.nextDouble() * 1.2),
    );
  }

  @override
  void didUpdateWidget(covariant PrecipitationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 비->눈 등 타입 바뀌면 재생성
    if ((oldWidget.now.pty ?? 0) != (widget.now.pty ?? 0)) {
      _ps = List.generate(_countByIntensity(), (_) => _spawn());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRainOrSnow) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.sizeOf(context),
        painter: _PrecipPainter(
          particles: _ps,
          isSnow: _isSnow,
          tick: _c.value,
          onStep: (w, h) {
            // 위치 업데이트 (화면 밖 나가면 재생성)
            for (var i = 0; i < _ps.length; i++) {
              final p = _ps[i];
              p.y += p.v * 0.012;
              p.x += p.drift * 0.012;

              if (p.y > 1.05 || p.x < -0.05 || p.x > 1.05) {
                _ps[i] = _spawn()..y = -0.02;
              }
            }
          },
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.v,
    required this.drift,
    required this.size,
  });

  double x, y;       // 0~1 정규화 좌표
  double v;          // 속도
  double drift;      // 좌우 흔들림
  double size;       // 크기
}

class _PrecipPainter extends CustomPainter {
  _PrecipPainter({
    required this.particles,
    required this.isSnow,
    required this.tick,
    required this.onStep,
  });

  final List<_Particle> particles;
  final bool isSnow;
  final double tick;
  final void Function(double w, double h) onStep;

  @override
  void paint(Canvas canvas, Size size) {
    onStep(size.width, size.height);

    final paint = Paint()
      ..color = Colors.white.withOpacity(isSnow ? 0.75 : 0.45)
      ..strokeWidth = isSnow ? 1.2 : 1.4
      ..strokeCap = StrokeCap.round;

    for (final p in particles) {
      final dx = p.x * size.width;
      final dy = p.y * size.height;

      if (isSnow) {
        canvas.drawCircle(Offset(dx, dy), p.size, paint);
      } else {
        // 비는 선으로
        final len = 10 + p.size * 6;
        canvas.drawLine(Offset(dx, dy), Offset(dx + 2, dy + len), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PrecipPainter oldDelegate) => true;
}


class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }
}

class _WeatherHero extends StatelessWidget {
  const _WeatherHero({required this.now, this.sunrise, this.sunset});
  final WeatherNow now;
  final DateTime? sunrise;
  final DateTime? sunset;

  String _ptyText(int pty) => switch (pty) {
    1 => '비',
    2 => '비/눈',
    3 => '눈',
    4 => '소나기',
    _ => '강수 없음',
  };

  String _hhmm(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final temp = now.temp;
    final tempRound = temp?.round();
    final feel = (now.temp != null && now.wind != null)
        ? (now.temp! - (now.wind! * 0.7))
        : null;
    final feelRound = feel?.round();

    final hum = now.humidity?.round();
    final wind = now.wind;
    final rn1 = now.rn1;
    final pty = now.pty ?? 0;

    String mmText(num? v) => v == null ? '--' : v.toStringAsFixed(1);
    String msText(num? v) => v == null ? '--' : v.toStringAsFixed(1);

    final topLine = [
      '현재 ${tempRound ?? '--'}°',
      '체감 ${feelRound ?? '--'}°',
      '일출 ${_hhmm(sunrise)}',
      '일몰 ${_hhmm(sunset)}',
    ].join(' · ');

    // ✅ 한 줄 요약(최대한 짧게)
    final summary = [
      '습도 ${hum ?? '--'}%',
      '바람 ${msText(wind)}m/s',
      '강수 ${rn1 == null ? '--' : rn1 <= 0 ? '0.0' : mmText(rn1)}mm',
      _ptyText(pty),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ✅ 아이콘은 그대로 유지
          _WeatherIcon(sky: now.sky, pty: now.pty, size: 58),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // ✅ 불필요하게 늘어나지 않게
              children: [
                // ✅ 온도 위 텍스트(일출/일몰 포함) — 길면 ... 처리해서 줄수 안 늘어남
                Text(
                  topLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 6),

                // ✅ 큰 온도 (중앙 1줄)
                Text(
                  '${tempRound ?? '--'}°',
                  style: t.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: -1.0,
                  ) ??
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                        letterSpacing: -1.0,
                      ),
                ),

                const SizedBox(height: 8),

                // ✅ 하단 1줄 요약 (2줄 넘어가면 ellipsis)
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: Colors.white70, height: 1.1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: t.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AirCard extends StatelessWidget {
  const _AirCard({required this.air});
  final AirQuality air;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final pm10Val = air.pm10;
    final pm25Val = air.pm25;

    final pm10Grade = gradePm10(pm10Val);
    final pm25Grade = gradePm25(pm25Val);

    final mask = maskMessage(pm10Grade, pm25Grade);

    String vText(num? v) => v == null ? '--' : v.round().toString();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('대기질', style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),

          // ✅ 미세먼지/초미세먼지 각각 표시
          Row(
            children: [
              Expanded(
                child: _DustTile(
                  title: '미세먼지',
                  value: '${vText(pm10Val)}',
                  grade: dustGradeText(pm10Grade),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DustTile(
                  title: '초미세먼지',
                  value: '${vText(pm25Val)}',
                  grade: dustGradeText(pm25Grade),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ 마스크 추천
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.masks, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(mask, style: t.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String maskMessage(DustGrade pm10, DustGrade pm25) {
    if (pm10 == DustGrade.unknown && pm25 == DustGrade.unknown) return '대기질 정보 없음';
    return recommendMask(pm10: pm10, pm25: pm25) ? '마스크 착용 권장' : '마스크는 선택';
  }

  bool recommendMask({required DustGrade pm10, required DustGrade pm25}) {
    bool isBadOrWorse(DustGrade g) => g == DustGrade.bad || g == DustGrade.veryBad;
    return isBadOrWorse(pm10) || isBadOrWorse(pm25);
  }

  DustGrade gradePm10(num? v) {
    if (v == null) return DustGrade.unknown;
    if (v <= 30) return DustGrade.good;
    if (v <= 80) return DustGrade.normal;
    if (v <= 150) return DustGrade.bad;
    return DustGrade.veryBad;
  }

  DustGrade gradePm25(num? v) {
    if (v == null) return DustGrade.unknown;
    if (v <= 15) return DustGrade.good;
    if (v <= 35) return DustGrade.normal;
    if (v <= 75) return DustGrade.bad;
    return DustGrade.veryBad;
  }

  String dustGradeText(DustGrade g) {
    switch (g) {
      case DustGrade.good: return '좋음';
      case DustGrade.normal: return '보통';
      case DustGrade.bad: return '나쁨';
      case DustGrade.veryBad: return '매우나쁨';
      case DustGrade.unknown: return '정보없음';
    }
  }
}

class _DustTile extends StatelessWidget {
  const _DustTile({
    required this.title,
    required this.value,
    required this.grade,
  });

  final String title;
  final String value;
  final String grade;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$value', style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text(grade, style: t.bodyMedium?.copyWith(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip({required this.items});
  final List<HourlyForecast> items;

  @override
  Widget build(BuildContext context) {
    final list = items.isEmpty
        ? [
      const HourlyForecast(timeLabel: 'NOW', sky: 1, pty: 0, temp: null),
      const HourlyForecast(timeLabel: '10시', sky: 3, pty: 0, temp: null),
      const HourlyForecast(timeLabel: '11시', sky: 4, pty: 0, temp: null),
    ]
        : items;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '시간대별',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: list.map((h) {
                return Container(
                  width: 64,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(h.timeLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      _WeatherIcon(sky: h.sky, pty: h.pty, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        h.temp == null ? '--°' : '${h.temp!.round()}°',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyStrip extends StatelessWidget {
  const _WeeklyStrip({required this.items});
  final List<DailyForecast> items;

  String weekTopLabel(String yyyymmdd) {
    DateTime? dt;
    try {
      dt = DateTime(
        int.parse(yyyymmdd.substring(0, 4)),
        int.parse(yyyymmdd.substring(4, 6)),
        int.parse(yyyymmdd.substring(6, 8)),
      );
    } catch (_) {
      return yyyymmdd;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d0 = DateTime(dt.year, dt.month, dt.day);

    final diff = d0.difference(today).inDays;

    if (diff == 0) return '오늘';
    if (diff == 1) return '내일';
    if (diff == 2) return '모레';

    // 나머지는 요일
    const w = ['월', '화', '수', '목', '금', '토', '일'];
    return w[d0.weekday - 1];
  }

  IconData _iconFromWf(String? wf) {
    final s = (wf ?? '').trim();
    if (s.contains('눈')) return Icons.ac_unit;
    if (s.contains('비')) return Icons.umbrella;
    if (s.contains('흐림')) return Icons.cloud;
    if (s.contains('구름')) return Icons.cloud_queue;
    if (s.contains('맑')) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('주간',
              style: t.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items.map((d) {
                DateTime? dt;
                try {
                  dt = DateTime(
                    int.parse(d.date.substring(0, 4)),
                    int.parse(d.date.substring(4, 6)),
                    int.parse(d.date.substring(6, 8)),
                  );
                } catch (_) {}

                final top = weekTopLabel(d.date);
                final sub = dt == null ? '' : '${dt.month}/${dt.day}';
                final minText = d.min == null ? '--' : d.min!.round().toString();
                final maxText = d.max == null ? '--' : d.max!.round().toString();
                final popText = d.pop == null ? '--' : '${d.pop}%';

                return Container(
                  width: 84,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        top,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                      const SizedBox(height: 8),

                      // ✅ 중기(wfText)면 아이콘 추정 / 단기면 SKY+PTY 아이콘
                      if ((d.wfText ?? '').isNotEmpty)
                        Icon(_iconFromWf(d.wfText), color: Colors.white, size: 24)
                      else
                        _WeatherIcon(sky: d.sky, pty: d.pty, size: 24),

                      const SizedBox(height: 8),
                      Text('$maxText° / $minText°',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('강수 $popText', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alerts});
  final List<WeatherAlert> alerts;

  String _prettyTime(String s) {
    // s: "YYYYMMDDHHmm" 형태 기대(아닐 수도 있으니 방어)
    if (s.length >= 12) {
      final mm = s.substring(4, 6);
      final dd = s.substring(6, 8);
      final hh = s.substring(8, 10);
      final mi = s.substring(10, 12);
      return '$mm/$dd $hh:$mi';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final first = alerts.first;
    final more = alerts.length > 1 ? ' · ${alerts.length - 1}건 더' : '';
    final t = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlertDetailPage(alerts: alerts),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('기상 특보',
                      style: t.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '${first.title}$more',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '발표 ${_prettyTime(first.timeText)}',
                    style: t.labelSmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class AlertDetailPage extends StatelessWidget {
  const AlertDetailPage({super.key, required this.alerts});
  final List<WeatherAlert> alerts;

  String _prettyTime(String s) {
    if (s.length >= 12) {
      final yy = s.substring(0, 4);
      final mm = s.substring(4, 6);
      final dd = s.substring(6, 8);
      final hh = s.substring(8, 10);
      final mi = s.substring(10, 12);
      return '$yy-$mm-$dd $hh:$mi';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기상 특보'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final a = alerts[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('발표: ${_prettyTime(a.timeText)}', style: t.bodySmall),
                if ((a.region ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('지역: ${a.region}', style: t.bodySmall),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeatherIcon extends StatelessWidget {
  const _WeatherIcon({required this.sky, required this.pty, this.size = 24});
  final int? sky;
  final int? pty;
  final double size;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final p = pty ?? 0;

    if (p == 1 || p == 4) {
      icon = Icons.grain; // 비/소나기
    } else if (p == 2) {
      icon = Icons.ac_unit; // 비/눈
    } else if (p == 3) {
      icon = Icons.cloudy_snowing; // 눈
    } else {
      final s = sky ?? 1;
      icon = switch (s) {
        1 => Icons.wb_sunny,
        3 => Icons.wb_cloudy,
        4 => Icons.cloud,
        _ => Icons.wb_cloudy,
      };
    }

    return Icon(icon, color: Colors.white, size: size);
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// 2025-12-23 jgh251223---S
class _TransitCard extends StatelessWidget {
  const _TransitCard({required this.data});
  final TransitRouteResult data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget badge(String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final arrivalText = [data.firstArrivalText, data.secondArrivalText]
        .where((e) => e.isNotEmpty)
        .join(' / ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              badge('최소 도보'),
              const SizedBox(width: 8),
              badge('최소 시간'),
              const SizedBox(width: 8),
              badge('최소 환승'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.summary,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            arrivalText.isEmpty ? '도착 정보 없음' : arrivalText,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.route, size: 15),
                label: const Text('경로 보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // 카드가 파란색이라 흰색이 잘 보임
                  foregroundColor: const Color(0xFF1976D2), // 글자/아이콘 색
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Routeview(raw: data.raw)),
                  );
                },
              ),

              OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_border, size: 15),
                label: const Text('즐겨찾기'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white, // 카드가 파란색이라 흰색이 잘 보임
                  foregroundColor: const Color(0xFF1976D2), // 글자/아이콘 색
                  side: BorderSide(color: Colors.white.withOpacity(0.7)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // TODO: 즐겨찾기 저장/삭제 로직 연결
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// 2025-12-23 jgh251223---E

class _CarryCardFromFirestore extends StatelessWidget {
  const _CarryCardFromFirestore({required this.items, required this.data});

  final List<ChecklistItem> items;
  final DashboardData data;

  IconData _iconFromKey(String key) {
    switch (key) {
      case 'umbrella': return Icons.umbrella;
      case 'mask': return Icons.masks;
      case 'laundry': return Icons.local_laundry_service;
      case 'train': return Icons.directions_subway;
      case 'bus': return Icons.directions_bus;
      case 'clock': return Icons.schedule;
      case 'warning': return Icons.warning_amber_rounded;
      case 'boots': return Icons.hiking;
      case 'hot': return Icons.local_fire_department;
      case 'water': return Icons.water_drop;
      case 'jacket':
      case 'shorts':
      case 'socks':
      case 'innerwear': return Icons.checkroom;
      default: return Icons.check_circle_outline;
    }
  }

  String _subtitle() {
    final pty = data.now.pty ?? 0;
    if (pty != 0) return '강수 가능성 있어요 · 우산/이동수단 챙기기';
    final pm25 = data.air.pm25 ?? 0;
    final pm10 = data.air.pm10 ?? 0;
    if (pm25 >= 36 || pm10 >= 81) return '대기질 나쁠 수 있어요 · 마스크 권장';
    return '현재 날씨/대기질 기준 추천';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final show = items.take(4).toList(); // 카드에는 3~4개가 보기 좋음

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('오늘 챙길 것',
                  style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const Spacer(),
              // MVP: 스위치 기능은 나중에(원하면 SharedPreferences로 저장 가능)
              Switch(
                value: true,
                onChanged: null, // 지금은 비활성
                activeColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (show.isEmpty)
            Text('오늘은 특별히 챙길 게 없어요 🙂', style: t.bodySmall?.copyWith(color: Colors.white70))
          else
            Row(
              children: show.map((e) {
                return Expanded(
                  child: Column(
                    children: [
                      Icon(_iconFromKey(e.icon), color: Colors.white, size: 26),
                      const SizedBox(height: 6),
                      Text(e.title, style: t.bodySmall?.copyWith(color: Colors.white70)),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 10),
          Text(_subtitle(), style: t.bodySmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}


class _NearbyIssuesCardHardcoded extends StatelessWidget {
  const _NearbyIssuesCardHardcoded();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // ✅ 하드코딩: 나중에 Firestore + 반경 1km로 교체
    final issues = const [
      ('역 출구 침수 심함', 7),
      ('사거리 교통사고 발생', 3),
      ('인도 결빙 구간 있음', 2),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 주변 1km · 최신 3건',
              style: t.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 10),
          ...List.generate(issues.length, (i) {
            final (title, up) = issues[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${i + 1}. $title (확인 $up)',
                style: t.bodySmall?.copyWith(color: Colors.white70),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: () {}, child: const Text('[지도 보기]')),
              TextButton(onPressed: () {}, child: const Text('[제보]')),
            ],
          ),
        ],
      ),
    );
  }
}
