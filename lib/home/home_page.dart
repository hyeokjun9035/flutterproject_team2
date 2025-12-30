import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/home/ui_helpers.dart';
import 'package:flutter_project/utils/launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../headandputter/putter.dart';
import 'home_card_order.dart'; //jgh251226


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

  Future<void> _openForecastWeb() async {
    if (_lat == null || _lon == null) return;
    final url = buildWeatherNuriDigitalForecastUrl(lat: _lat!, lon: _lon!);
    await openExternal(url);
  }

  Future<void> _openAirKoreaWeb() async {
    await openExternal(airKoreaMyNeighborhoodUrl());
  }

  static const double kDefaultLat = 37.5665; // 서울시청
  static const double kDefaultLon = 126.9780;
  static const String kDefaultLocationLabel = '기본 위치(서울)';

  bool _usingDefaultLocation = false;

  double? _lat;
  double? _lon;
  String _locationLabel = '위치 확인 중...'; // 화면 표시용 (부평역)
  String _airAddr = '';                      // 에어코리아 검색용 (인천광역시 부평구)
  String _adminArea = '';
  DateTime? _sunrise;
  DateTime? _sunset;
  bool _editMode = false;
  List<HomeCardId> _order = [...HomeCardOrderStore.defaultOrder];
  List<ChecklistItem> _lastChecklist = const [];
  bool _isRefreshing = false;

  Widget tappableCard({required Widget child, required VoidCallback onTap}) {
    return IgnorePointer(
      ignoring: _editMode,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }

  Widget _buildHomeCard(HomeCardId id, DashboardData? data, bool isFirstLoading) {
    switch (id) {
      case HomeCardId.weatherHero: {
        final canTap = !_editMode && !isFirstLoading && _lat != null && _lon != null;
        return _Card(
          onTap: canTap ? _openForecastWeb : null,
          child: isFirstLoading
              ? const _Skeleton(height: 120)
              : _WeatherHero(now: data!.now, sunrise: _sunrise, sunset: _sunset),
        );
      }

      case HomeCardId.carry:
        return _Card(
          child: isFirstLoading
              ? const _Skeleton(height: 140)
              : FutureBuilder<List<ChecklistItem>>(
            future: _checkFuture,
            initialData: _lastChecklist.isNotEmpty ? _lastChecklist : null,
            builder: (context, snap) {
              final items = snap.data ?? _lastChecklist;

              // ✅ “진짜 최초 로딩”에만 스켈레톤
              final first = (items.isEmpty) && (snap.connectionState != ConnectionState.done);
              if (first) return const _Skeleton(height: 150);

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
        );

      case HomeCardId.air: {
        final canTap = !_editMode && !isFirstLoading;
        return _Card(
          onTap: canTap ? _openAirKoreaWeb : null,
          child: isFirstLoading
              ? const _Skeleton(height: 90)
              : _AirCard(air: data!.air),
        );
      }

      case HomeCardId.hourly:
        return _Card(
          child: isFirstLoading ? const _Skeleton(height: 90) : _HourlyStrip(items: data!.hourly),
        );

      case HomeCardId.weekly:
        return _Card(
          child: isFirstLoading ? const _Skeleton(height: 130) : _WeeklyStrip(items: data!.weekly),
        );

      case HomeCardId.transit:
        return _Card(
          child: isFirstLoading
              ? const _Skeleton(height: 130)
              : FutureBuilder<TransitRouteResult>(
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
        );

      case HomeCardId.nearbyIssues:
        return _Card(
          child: isFirstLoading ? const _Skeleton(height: 120) : _NearbyIssuesCardHardcoded(),
        );
    }
  }


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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint("✅ HomePage currentUser uid = $uid");

    // 로그인 필수로 막는다면 (추천)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    _loadOrder();
    _service = DashboardService(region: 'asia-northeast3');
    _checklistService = ChecklistService();
    _checkFuture = _fetchChecklistKeepingCache();
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
      final fresh = await _initLocationAndFetch(
        forceFreshPosition: true,
        ignoreDashboardCache: true,
        ignoreGeocodeCache: false,
      );
      if (!mounted) return;
      setState(() => _future = Future.value(fresh));
    } catch (_) {
      // 실패해도 캐시 화면은 이미 떠 있으니 무시
    }
  }

  Future<void> _loadOrder() async {
    final loaded = await HomeCardOrderStore.load();
    if (!mounted) return;
    setState(() => _order = loaded);
  }

  void _toggleEditMode() async {

    setState(() => _editMode = true);

    await _openOrderSheet;

    if (!mounted) return;
    setState(() => _editMode = false);
  }

  Future<void> _openOrderSheet() async {
    debugPrint('[HomeOrder] open sheet');

    final result = await showModalBottomSheet<List<HomeCardId>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (_) => _CardOrderSheet(initial: _order),
    );

    if (result == null) return;

    setState(() => _order = result);
    await HomeCardOrderStore.save(_order);

    debugPrint('[HomeOrder] saved: ${_order.map((e) => e.name).toList()}');
  }

  Future<List<ChecklistItem>> _fetchChecklistKeepingCache() async {
    try {
      final items = await _checklistService.fetchEnabledItems();
      if (items.isNotEmpty) _lastChecklist = items;
      return items;
    } catch (_) {
      return _lastChecklist; // ✅ 실패 시 캐시 반환
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

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    final hasPerm = (perm == LocationPermission.whileInUse || perm == LocationPermission.always);
    final canUseLocation = enabled && hasPerm;

    String? locationGateReason;
    if (!enabled) locationGateReason = '위치 서비스 OFF';
    if (!hasPerm) locationGateReason = '위치 권한 필요';

    if (!canUseLocation && mounted) {
      setState(() => _locationLabel = locationGateReason ?? '위치 사용 불가');
    }

    // 위치 가져오기
    Position? pos;

    Future<Position?> _tryCurrent({required int seconds, required LocationAccuracy acc}) async {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: acc,
          timeLimit: Duration(seconds: seconds),
        );
      } on TimeoutException {
        return null;
      } catch (_) {
        return null;
      }
    }

    Future<Position?> _tryStreamOnce({required int seconds, required LocationAccuracy acc}) async {
      try {
        return await Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: acc,
            distanceFilter: 0,
          ),
        ).first.timeout(Duration(seconds: seconds));
      } on TimeoutException {
        return null;
      } catch (_) {
        return null;
      }
    }

    if (canUseLocation) {
      final last = await Geolocator.getLastKnownPosition();

      if (!forceFreshPosition && last != null) {
        // 최초 진입은 lastKnown 우선(빠름)
        pos = last;
      } else {
        // 새로고침: stream -> current 순서로 짧게 시도 (너무 오래 끌지 않기)
        pos = await _tryStreamOnce(
          seconds: 3,
          acc: LocationAccuracy.best,
        );

        pos ??= await _tryCurrent(
          seconds: 6,
          acc: LocationAccuracy.best,
        );

        // 마지막으로 lastKnown 한번 더
        pos ??= await Geolocator.getLastKnownPosition();
      }
    }

    if (pos != null) {
      _lat = pos.latitude;
      _lon = pos.longitude;
      _usingDefaultLocation = false;
    } else {
      // ✅ 마지막 fallback: 기존 좌표/캐시 좌표 → 그래도 없으면 "기본 좌표" 사용
      if (_lat != null && _lon != null) {
        // 기존 좌표 유지 (기본 좌표를 쓰고 있었으면 그대로 유지)
        setState(() => _locationLabel = '위치 갱신 지연 · 이전 위치');
      } else if (!ignoreDashboardCache && DashboardCache.lat != null && DashboardCache.lon != null) {
        _lat = DashboardCache.lat;
        _lon = DashboardCache.lon;
        _usingDefaultLocation = false;
        setState(() => _locationLabel = '위치 갱신 지연 · 캐시 위치');
      } else {
        // ✅ 초기 위치를 못 잡으면 기본 좌표로 먼저 표시
        _lat = kDefaultLat;
        _lon = kDefaultLon;
        _usingDefaultLocation = true;

        final reason = locationGateReason ?? '위치 확인 실패';
        setState(() => _locationLabel = '$kDefaultLocationLabel · $reason');
      }
    }

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
      final placemarks = await placemarkFromCoordinates(_lat!, _lon!)
          .timeout(const Duration(seconds: 2), onTimeout: () => <Placemark>[]);
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

    final uiLabel = (locationGateReason == null)
        ? label
        : '$label · $locationGateReason';

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

  Future<void> _reload() async {
    setState(() {
      _isRefreshing = true;
      _checkFuture = _fetchChecklistKeepingCache();
    });

    try {
      await _refreshInBackground(); // 가능하면 await (안정)
    } catch (_) {
      // 무시: 기존 캐시 화면 유지
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1E88E5);

    return PutterScaffold(
      currentIndex: 0,
      body: Scaffold(
        body: FutureBuilder<DashboardData>(
          future: _future,
          initialData: DashboardCache.data,
          builder: (context, snapshot) {
            final data = snapshot.data ?? DashboardCache.data;

            // 초기 진입만 로딩 처리
            final isFirstLoading = (data == null);
            // 새로고침/백그라운드 갱신
            final isRefreshing = _isRefreshing;

            if (snapshot.hasError && data == null) {
              final err = snapshot.error;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 36),
                    const SizedBox(height: 12),
                    Text('데이터 로드 실패\n$err', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _reload, child: const Text('다시시도'))
                  ],
                )
              );
            }

            final now = data?.now;
      
            // ✅ 로딩 조건 강화: done이 아니거나 data가 없으면 로딩
            final isLoading =
                snapshot.connectionState != ConnectionState.done || data == null;

            final safeData = snapshot.data ?? DashboardCache.data;
            final updatedAt = safeData?.updatedAt ?? DateTime.now();
      
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
                              updatedAt: updatedAt,
                              onRefresh: _reload,
                              isRefreshing: isRefreshing,
                              editMode: _editMode,
                              onToggleEditMode: _toggleEditMode,
                              onOpenOrderSheet: _openOrderSheet,
                            ),
                          ),
                        ),

                        if (safeData != null && safeData.alerts.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _AlertBanner(alerts: safeData.alerts),
                            ),
                          ),
      
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final id = _order[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildHomeCard(id, data, isFirstLoading),
                                );
                              },
                              childCount: _order.length,
                            ),
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
    required this.isRefreshing,
    required this.editMode,
    required this.onRefresh,
    required this.onToggleEditMode,
    required this.onOpenOrderSheet,
  });

  final String locationName;
  final DateTime updatedAt;
  final bool isRefreshing;
  final bool editMode;

  final VoidCallback onRefresh;
  final VoidCallback onToggleEditMode;
  final VoidCallback onOpenOrderSheet;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hh = updatedAt.hour.toString().padLeft(2, '0');
    final mm = updatedAt.minute.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // ✅ 업데이트 라인에 아이콘 추가
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '업데이트 $hh:$mm',
                      style: t.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ✅ 우측 버튼들
          IconButton(
            tooltip: '카드 순서 편집',
            onPressed: onOpenOrderSheet, // ✅ B안: 누르면 바로 시트 뜸
            icon: const Icon(Icons.swap_vert, color: Colors.white),
          ),

          IconButton(
            tooltip: '새로고침',
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
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
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220).withOpacity(0.22), // ✅ 살짝 어두운 반투명
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.10)), // ✅ 얇은 테두리
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _WeatherHero extends StatelessWidget {
  const _WeatherHero({
    required this.now,
    required this.sunrise,
    required this.sunset,
  });

  final WeatherNow now;
  final DateTime? sunrise;
  final DateTime? sunset;

  String _hhmm(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final temp = now.temp?.round();
    final feel = (now.temp != null && now.wind != null)
        ? (now.temp! - (now.wind! * 0.7)).round()
        : null;

    final summary = weatherSummary(sky: now.sky, pty: now.pty);

    final hum = now.humidity?.round();
    final wind = now.wind;

    final chips = <Widget>[
      valueChip(icon: Icons.water_drop, text: '습도 ${hum ?? '--'}%'),
      valueChip(icon: Icons.air, text: '바람 ${wind?.toStringAsFixed(1) ?? '--'}m/s'),
      if (now.rn1 != null) valueChip(icon: Icons.umbrella, text: '강수 1h ${now.rn1!.toStringAsFixed(1)}mm'),
      valueChip(icon: Icons.wb_twilight, text: '일출 ${_hhmm(sunrise)}'),
      valueChip(icon: Icons.nightlight_round, text: '일몰 ${_hhmm(sunset)}'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ✅ 왼쪽: 아이콘 + 요약 멘트
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WeatherIcon(sky: now.sky, pty: now.pty, size: 56),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Text(
                  summary,
                  style: t.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // ✅ 오른쪽: 온도/체감 + 칩들
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 현재/체감 (두 줄 방지로 구조화)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('현재',
                            style: t.labelSmall?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                            )),
                        Text(
                          '${temp ?? '--'}°',
                          style: const TextStyle(
                            fontSize: 56,        // ✅ 크게
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('체감',
                            style: t.labelSmall?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                            )),
                        Text(
                          '${feel ?? '--'}°',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ✅ 칩: 습도/바람/강수/일출/일몰
                SizedBox(
                height: 34, // ✅ 칩 높이에 맞춰 조절
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: chips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => chips[i],
                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AirCard extends StatelessWidget {
  const _AirCard({required this.air});
  final AirQuality air;

  Widget _gradeChip({
    required String title,
    required int? value,
    required DustGrade grade,
  }) {
    final vText = value == null ? '--' : '$value';
    final gText = gradeLabel(grade);
    final c = gradeColor(grade);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12,)),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(vText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(gText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final pm10Grade = gradePm10(air.pm10);
    final pm25Grade = gradePm25(air.pm25);

    final maskText = maskRecommendation(pm25: air.pm25);
    final maskIcon = (pm25Grade == DustGrade.bad || pm25Grade == DustGrade.veryBad)
        ? Icons.masks
        : Icons.masks_outlined;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('대기질',
                  style: t.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
              // (선택) gradeText가 있으면 우측 상단에 짧게 표시
              if ((air.gradeText ?? '').isNotEmpty)
                Text(
                  air.gradeText!,
                  style: t.labelSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w800),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ 미세/초미세 등급 칩 (가로)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _gradeChip(
                  title: '미세먼지',
                  value: air.pm10,
                  grade: pm10Grade,
                ),
                const SizedBox(width: 10),
                _gradeChip(
                  title: '초미세먼지',
                  value: air.pm25,
                  grade: pm25Grade,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ✅ 마스크 추천 문구 (KF80/KF94)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Row(
              children: [
                Icon(maskIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '마스크: $maskText',
                    style: t.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                ),
                // (선택) 한 줄 도움말 느낌
                if (pm25Grade == DustGrade.veryBad)
                  Text('외출 최소화',
                      style: t.labelSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w800)),
              ],
            ),
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

    final temps = list.map((e) => e.temp).toList();
    final rain = list.map((e) => ((e.pty ?? 0) != 0) ? 1.0 : 0.0).toList();

    const tileW = 64.0;
    const gap = 10.0;
    final n = list.length;
    final rowW = n * tileW + (n - 1) * gap;
    final hasRain = rain.any((v) => v > 0);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1) 타일 Row
                Row(
                  children: List.generate(n, (i) {
                    final h = list[i];
                    return Container(
                      width: tileW,
                      margin: EdgeInsets.only(right: i == n - 1 ? 0 : gap), // ✅ 마지막 gap 제거
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
                  }),
                ),

                const SizedBox(height: 10),

                // ✅ 2) 온도 텍스트 아래쪽에 “온도 라인 그래프”
                SizedBox(
                  width: rowW,
                  height: 54,
                  child: _MiniTempLine(values: temps, tileW: tileW, gap: gap),
                ),

                const SizedBox(height: 8),

                // ✅ 3) 그 아래에 “강수 막대 그래프(임시: pty 기반)”
                SizedBox(
                  width: rowW,
                  height: 24,
                  child: hasRain ? _MiniRainBars(values: rain, tileW: tileW, gap: gap) : const _MiniRainEmpty(),
                ),
              ],
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

                final amText = d.wfAm ?? d.wfText ?? '';
                final pmText = d.wfPm ?? d.wfText ?? '';
                final amPop = d.popAm ?? d.pop;
                final pmPop = d.popPm ?? d.pop;
                Widget iconFor(String wfFallback) {
                  if (wfFallback.trim().isNotEmpty) {
                    return Icon(_iconFromWf(wfFallback), color: Colors.white, size: 22);
                  }
                  // 단기만 있는 경우(분리 데이터 없을 때) fallback
                  return _WeatherIcon(sky: d.sky, pty: d.pty, size: 22);
                }

                String popText(int? v) => v == null ? '--' : '$v%';

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              const Text('오전', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 4),
                              iconFor(amText),
                              const SizedBox(height: 4),
                              Text(popText(amPop), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: [
                              const Text('오후', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 4),
                              iconFor(pmText),
                              const SizedBox(height: 4),
                              Text(popText(pmPop), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ],
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

// ChecklistItem, DashboardData 타입은 너 프로젝트에 이미 있는 걸 사용
class _CarryCardFromFirestore extends StatefulWidget {
  const _CarryCardFromFirestore({required this.items, required this.data});

  final List<ChecklistItem> items;
  final DashboardData data;

  @override
  State<_CarryCardFromFirestore> createState() => _CarryCardFromFirestoreState();
}

class _CarryCardFromFirestoreState extends State<_CarryCardFromFirestore> {
  static const _prefKey = 'carry_enabled'; // ✅ 로컬 저장 키
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_prefKey);
    if (!mounted) return;
    setState(() {
      _enabled = v ?? true; // 기본 ON
    });
  }

  Future<void> _setEnabled(bool v) async {
    setState(() => _enabled = v); // ✅ 즉시 반영
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, v); // ✅ 로컬 저장
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // ✅ 규칙 필터된 items가 이미 들어온다고 가정(너 HomePage에서 list 만들어서 넘김)
    final show = widget.items.take(4).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '오늘 챙길 것',
                style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Switch(
                value: _enabled,
                onChanged: (v) => _setEnabled(v),
                activeColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_enabled)
            Text(
              '추천 숨김 (스위치 ON으로 다시 표시)',
              style: t.bodySmall?.copyWith(color: Colors.white70),
            )
          else if (show.isEmpty)
            Text(
              '오늘은 특별히 챙길 게 없어요 🙂',
              style: t.bodySmall?.copyWith(color: Colors.white70),
            )
          else
            Row(
              children: show.map((e) {
                final s = styleFromType(e.type);

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Column(
                      children: [
                        Align(alignment: Alignment.centerLeft, child: typeChip(e.type)),
                        const SizedBox(height: 8),

                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: s.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: s.border)
                          ),
                          child: Icon(iconFromKey(e.icon), color: s.fg, size: 22),
                        ),
                        const SizedBox(height: 8),

                        Text(
                            e.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        const SizedBox(height: 6),

                        // ✅ “근거 표시”는 일단 message를 보여주면 가장 간단/확실
                        Text(
                          e.message,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
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

    const issues = [
      _Issue('역 출구 침수 심함', 7),
      _Issue('사거리 교통사고 발생', 3),
      _Issue('인도 결빙 구간 있음', 2),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 주변 1km · 최신 3건',
              style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),

          for (int i = 0; i < issues.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${i + 1}. ${issues[i].title} (확인 ${issues[i].up})',
                style: t.bodySmall?.copyWith(color: Colors.white70),
              ),
            ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('지도 보기'),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('제보'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Issue {
  final String title;
  final int up;
  const _Issue(this.title, this.up);
}

class _MiniTempLine extends StatelessWidget {
  const _MiniTempLine({
    required this.values,
    required this.tileW,
    required this.gap,
  });

  final List<double?> values;
  final double tileW;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MiniLinePainter(values, tileW, gap));
  }
}

class _MiniLinePainter extends CustomPainter {
  _MiniLinePainter(this.values, this.tileW, this.gap);

  final List<double?> values;
  final double tileW;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final nums = values.whereType<double>().toList();
    if (nums.length < 2) return;

    final minV = nums.reduce((a, b) => a < b ? a : b);
    final maxV = nums.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;


    final dot = Paint()..color = Colors.white;

    final path = Path();
    bool started = false;

    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;

      // ✅ 타일 중심 x
      final x = i * (tileW + gap) + tileW / 2;
      final y = size.height - ((v - minV) / range) * size.height;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (!started) return;
    canvas.drawPath(path, paint);

    // 점
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final x = i * (tileW + gap) + tileW / 2;
      final y = size.height - ((v - minV) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 4.8, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.tileW != tileW || oldDelegate.gap != gap;
}

class _MiniRainBars extends StatelessWidget {
  const _MiniRainBars({
    required this.values,
    required this.tileW,
    required this.gap,
  });

  final List<double> values;
  final double tileW;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MiniBarsPainter(values, tileW, gap));
  }
}

class _MiniBarsPainter extends CustomPainter {
  _MiniBarsPainter(this.values, this.tileW, this.gap);

  final List<double> values;
  final double tileW;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.35);

    for (int i = 0; i < values.length; i++) {
      final v = values[i].clamp(0.0, 1.0);
      final h = v * size.height;

      // ✅ 각 타일 영역 안에 bar 배치
      final left = i * (tileW + gap) + tileW * 0.22;
      final w = tileW * 0.56;

      final r = Rect.fromLTWH(left, size.height - h, w, h);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), p);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBarsPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.tileW != tileW || oldDelegate.gap != gap;
}

class _MiniRainEmpty extends StatelessWidget {
  const _MiniRainEmpty();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '강수 없음',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white60,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CardOrderSheet extends StatefulWidget {
  const _CardOrderSheet({required this.initial});
  final List<HomeCardId> initial;

  @override
  State<_CardOrderSheet> createState() => _CardOrderSheetState();
}

class _CardOrderSheetState extends State<_CardOrderSheet> {
  late List<HomeCardId> temp;

  @override
  void initState() {
    super.initState();
    temp = [...widget.initial];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('카드 순서 편집',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, temp),
                  child: const Text('저장'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 420,
              child: ReorderableListView(
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = temp.removeAt(oldIndex);
                    temp.insert(newIndex, item);
                  });
                },
                children: [
                  for (final id in temp)
                    ListTile(
                      key: ValueKey(id.name),
                      title: Text(HomeCardOrderStore.label(id),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      trailing: ReorderableDragStartListener(
                        index: temp.indexOf(id),
                        child: const Icon(Icons.drag_handle, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

