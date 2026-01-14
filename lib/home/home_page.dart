import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/community/CommunityView.dart';
import 'package:flutter_project/data/favorite_route.dart';
import 'package:flutter_project/home/ui_helpers.dart';
import 'package:flutter_project/utils/launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cache/dashboard_cache.dart';
import '../carry/checklist_models.dart';
import '../carry/checklist_rules.dart';
import '../community/CommunityAdd.dart';
import '../community/Event.dart';
import '../data/dashboard_service.dart';
import '../data/models.dart';
import '../data/bus_arrival_service.dart';
// 2025-12-23 jgh251223---S
import '../data/nearby_issues_service.dart';
import '../data/transit_service.dart';
// 2025-12-23 jgh251223---E
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 2025-12-23 jgh251223---S
// 2025-12-23 jgh251223---E
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../carry/checklist_service.dart';
import '../data/user_settings_store.dart';
import '../tmaprouteview/routeview.dart'; //jgh251224
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';
import '../headandputter/putter.dart';
import '../ui/nearby_issue_map_page.dart';
import '../widgets/app_drawer_factory.dart';
import 'home_card_order.dart'; //jgh251226
part 'home_widgets.part.dart';
part 'home_transit.part.dart';
part 'home_cards_extra.part.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DashboardService _service;
  late final ChecklistService _checklistService;
  late final UserSettingsStore _settingsStore;
  late Future<List<ChecklistItem>> _checkFuture;
  late final String _tmapApiKey;
  late final BusArrivalService _busArrivalService;
  StreamSubscription? _favSub;
  List<FavoriteRoute> _favorites = [];
  FavoriteRoute? _selectedFavorite;
  late Future<TransitRouteResult> _transitFuture;
  Future<DashboardData>? _future;
  String? _savedFavoriteId;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String? _weatherNuriCode;
  late final NearbyIssuesService _nearbyIssuesService;
  Stream<List<NearbyIssuePost>>? _nearbyIssuesStream;
  List<NearbyIssuePost> _nearbyIssuesLatest3 = const [];
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

  Future<void> _openForecastWeb() async {
    if (_lat == null || _lon == null) return;

    await openWeatherNuri(
      lat: _lat!,
      lon: _lon!,
      code: _weatherNuriCode, // String? 멤버로 존재해야 함
    );
  }

  void _rebuildNearbyIssuesStream() {
    if (_lat == null || _lon == null) return;
    _nearbyIssuesStream = _nearbyIssuesService.watchNearbyIssueTop3(
      myLat: _lat!,
      myLng: _lon!,
      radiusMeters: 1000,
      maxCandidates: 200,
      daysBack: 7,
    );
  }

  Future<void> _openAirKoreaWeb() async {
    await openExternal(airKoreaHomeUrl());
  }

  void _listenFavoritesAndBindTransit() {
    final uid = _uid;
    if (uid == null) return;

    _favSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('cdate', descending: true)
        .snapshots()
        .listen((snap) {
      final list = snap.docs.map((d) => FavoriteRoute.fromDoc(d.id, d.data())).toList();

      FavoriteRoute? nextSelected;

      if (list.isEmpty) {
        nextSelected = null;
        _savedFavoriteId = null;
      } else {
        // 1) 현재 선택이 살아있으면 유지
        final currentId = _selectedFavorite?.id;
        if (currentId != null && list.any((e) => e.id == currentId)) {
          nextSelected = list.firstWhere((e) => e.id == currentId);
        }
        // 2) 없으면 저장된 id로 선택
        else if (_savedFavoriteId != null &&
            list.any((e) => e.id == _savedFavoriteId)) {
          nextSelected = list.firstWhere((e) => e.id == _savedFavoriteId);
        }
        // 3) 그것도 없으면 최신 1개
        else {
          nextSelected = list.first;
        }
      }

      setState(() {
        _favorites = list;
        _selectedFavorite = nextSelected;
        _transitFuture = _buildTransitFutureFromSelectedFavorite();
      });

      final decidedId = nextSelected?.id;
      if (decidedId != _savedFavoriteId) {
        _savedFavoriteId = decidedId;
        _settingsStore.saveSelectedFavoriteId(uid, decidedId);
      }
    });
  }

  Future<void> _initFavoritesBinding() async {
    final uid = _uid;
    if (uid == null) return;
    _savedFavoriteId = await _settingsStore.loadSelectedFavoriteId(uid);
    _listenFavoritesAndBindTransit(); // 기존 함수
  }

  Future<TransitRouteResult> _buildTransitFutureFromSelectedFavorite() {
    final fav = _selectedFavorite;
    if (fav == null) {
      return Future.error('즐겨찾기 루트를 먼저 추가해주세요.');
    }

    // ✅ 1) 너무 짧으면 도보로 대체 (TMAP 호출 스킵)
    const minTransitDistanceM = 700.0; // 취향: 500~900m 추천
    final distM = haversineMeters(
      fav.start.lat, fav.start.lng,
      fav.end.lat, fav.end.lng,
    );

    if (distM < minTransitDistanceM) {
      // 도보 속도: 80m/min ≈ 4.8km/h
      final walkMin = max(1, (distM / 80.0).ceil());
      return Future.error(TransitTooShort(distM, walkMin));
    }

    // ✅ 2) 원래대로 TMAP 호출
    final dest = TransitDestination(
      name: fav.end.label.isEmpty ? fav.title : fav.end.label,
      lat: fav.end.lat,
      lon: fav.end.lng,
    );

    final service = TransitService(
      apiKey: _tmapApiKey,
      destination: dest,
    );

    return service.fetchRoute(
      startLat: fav.start.lat,
      startLon: fav.start.lng,
      startName: fav.start.label.isEmpty ? fav.title : fav.start.label,
      count: 10,
    );
  }

  Future<void> _pickFavorite() async {
    if (_favorites.isEmpty) return;

    final picked = await showModalBottomSheet<FavoriteRoute>(
      context: context,
      builder: (_) => ListView(
        children: _favorites.map((f) {
          return ListTile(
            title: Text(f.title),
            subtitle: Text(f.subtitle),
            onTap: () => Navigator.pop(context, f),
          );
        }).toList(),
      ),
    );

    if (picked == null) return;

    setState(() {
      _selectedFavorite = picked;
      _transitFuture = _buildTransitFutureFromSelectedFavorite();
    });

    _savedFavoriteId = picked.id;
    final uid = _uid;
    if (uid == null) return;
    await _settingsStore.saveSelectedFavoriteId(uid, picked.id);
  }

  Future<void> _goToLocationSettings() async {
    // ✅ 너 프로젝트의 실제 route name으로 바꿔줘
    await Navigator.pushNamed(context, '/locationSettings');
    // 돌아오면 favorites stream이 갱신되면서 _transitFuture도 자동 갱신됨
  }

  Future<void> _deleteSelectedFavorite() async {
    final fav = _selectedFavorite;
    if (fav == null) return;
    final uid = _uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(fav.id)
        .delete();
  }

  Future<void> _openFavoriteActionsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),

              // ✅ 즐겨찾기 변경(있을 때만)
              if (_favorites.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.white),
                  title: const Text('즐겨찾기 변경', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickFavorite();
                  },
                ),

              // ✅ 즐겨찾기 추가
              ListTile(
                leading: const Icon(Icons.add, color: Colors.white),
                title: const Text('즐겨찾기 추가', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await _goToLocationSettings();
                },
              ),

              // ✅ 즐겨찾기 관리(마이페이지/설정 화면)
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text('즐겨찾기 관리', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await _goToLocationSettings();
                },
              ),

              // ✅ 선택된 즐겨찾기 삭제(있을 때만)
              if (_selectedFavorite != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('선택된 즐겨찾기 삭제', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteSelectedFavorite();
                  },
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _favSub?.cancel();
    super.dispose();
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

  Widget _buildHomeCard(HomeCardId id, DashboardData? data, bool isFirstLoading) {
    switch (id) {
      case HomeCardId.weatherHero: {
        final canTap = !_editMode && !isFirstLoading && _lat != null && _lon != null;
        // ✅ data가 있을 때만 today 계산
        final today = (data?.weekly.isNotEmpty ?? false) ? data!.weekly.first : null;

        return _Card(
          onTap: canTap ? _openForecastWeb : null,
          child: isFirstLoading
              ? const _Skeleton(height: 120)
              : _WeatherHero(
            now: data!.now,
            sunrise: _sunrise,
            sunset: _sunset,
            todayMax: today?.max,
            todayMin: today?.min,
          ),
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

      case HomeCardId.hourly: {
        final canTap = !_editMode && !isFirstLoading && _lat != null && _lon != null;

        return _Card(
          onTap: canTap ? _openForecastWeb : null,
          child: isFirstLoading
              ? const _Skeleton(height: 90)
              : _HourlyStrip(items: data!.hourly),
        );
      }

      case HomeCardId.weekly: {
        final canTap = !_editMode && !isFirstLoading && _lat != null && _lon != null;

        return _Card(
          onTap: canTap ? _openForecastWeb : null,
          child: isFirstLoading
              ? const _Skeleton(height: 130)
              : _WeeklyStrip(items: data!.weekly),
        );
      }

      case HomeCardId.transit:
        return _Card(
          child: isFirstLoading
              ? const _Skeleton(height: 130)
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ [추가 1] 즐겨찾기 선택 헤더 (제목/출발→도착 + 변경 버튼)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 왼쪽 텍스트
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFavorite == null
                                ? '즐겨찾기 루트'
                                : '즐겨찾기 루트 (${_selectedFavorite!.title})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedFavorite?.subtitle ?? '즐겨찾기를 추가해 루트를 만들어보세요',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ✅ favorites가 있으면 '변경' -> _pickFavorite
                    // ✅ 없으면 '추가' -> locationSettings로 이동
                    if (_favorites.isEmpty)
                      ElevatedButton(
                        onPressed: _goToLocationSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1976D2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          elevation: 0,
                        ),
                        child: const Text('추가'),
                      )
                    else
                    OutlinedButton(
                        onPressed: _pickFavorite,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.45)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        child: const Text('변경'),
                      ),
                  ],
                ),
              ),

              // ✅ divider 느낌(선택)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withOpacity(0.10),
              ),

              // ✅ 기존 FutureBuilder 그대로
              FutureBuilder<TransitRouteResult>(
                future: _transitFuture,
                builder: (context, transitSnap) {
                  final isTransitLoading =
                      transitSnap.connectionState != ConnectionState.done;
                  if (isTransitLoading) {
                    return const _Skeleton(height: 120);
                  }
                  if (transitSnap.hasError || !transitSnap.hasData) {
                    final err = transitSnap.error;

                    if (err is TransitTooShort) {
                      final fav = _selectedFavorite;
                      return _WalkFallbackCard(
                        title: fav?.title ?? '도보 이동',
                        subtitle: fav?.subtitle ?? '',
                        distanceMeters: err.distanceMeters,
                        walkMinutes: err.walkMinutes,
                        onFavoritePressed: _openFavoriteActionsSheet,
                        startLat: fav?.start.lat ?? 0.0,
                        startLon: fav?.start.lng ?? 0.0,
                        endLat: fav?.end.lat ?? 0.0,
                        endLon: fav?.end.lng ?? 0.0,
                      );
                    }

                    // 기존 에러 UI 유지
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('교통 정보를 불러오지 못했습니다.\n$err', style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('즐겨찾기 관리'),
                            onPressed: _goToLocationSettings,
                          ),
                        ],
                      ),
                    );
                  }
                  final fav = _selectedFavorite;

                  return _TransitCard(
                      data: transitSnap.data!,
                      onFavoritePressed: _openFavoriteActionsSheet,
                      busArrivalService: _busArrivalService,
                      startLat: fav?.start.lat ?? 0.0,
                      startLon: fav?.start.lng ?? 0.0,
                      favoriteId: fav?.id,
                  );
                },
              ),
            ],
          ),
        );

      case HomeCardId.nearbyIssues:
        return _Card(
          child: isFirstLoading ? const _Skeleton(height: 120) : _NearbyIssuesCard(
              stream: _nearbyIssuesStream ?? const Stream.empty(),
              initialIssues: _nearbyIssuesLatest3,
            onData: (issues) {
                _nearbyIssuesLatest3 = issues;
            },
            onOpenPost: (docId) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Communityview(docId: docId),
                ),
              );
            },
            onMapPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NearbyIssuesMapPage(
                    myLat: _lat!,
                    myLng: _lon!,
                    posts: _nearbyIssuesLatest3,
                  ),
                ),
              );
            },
            onReportPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Event()),
              );
            },
            onAddPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Communityadd())
              );
            }
          ),
        );
    }
  }

  static const TransitDestination _defaultDestination = TransitDestination(
    name: '강동구청',
    lat: 37.530020,
    lon: 127.123920,
  );

  @override
  void initState() {
    super.initState();
    _settingsStore = UserSettingsStore();
    _loadOrderFromDb();

    final uid = _uid;
    debugPrint("✅ HomePage currentUser uid = $uid");

    // 로그인 필수로 막는다면 (추천)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
    _service = DashboardService(region: 'asia-northeast3');
    _checklistService = ChecklistService();
    _checkFuture = _fetchChecklistKeepingCache();
    _tmapApiKey = dotenv.env['TMAP_API_KEY'] ??
        const String.fromEnvironment('TMAP_API_KEY', defaultValue: '');

    // ✅ transitFuture 초기값(즐겨찾기 없을 때 메시지)
    _transitFuture = Future.error('즐겨찾기 루트를 먼저 추가해주세요.');

    // ✅ 즐겨찾기 구독 시작 (B안: start->end)
    _initFavoritesBinding();

    final rawKey = dotenv.env['TAGO_SERVICE_KEY'] ?? '';
    final tagoKey = Uri.decodeFull(rawKey);

    _busArrivalService = BusArrivalService(serviceKey: tagoKey);
    _nearbyIssuesService = NearbyIssuesService();
    // 2025-12-23 jgh251223---E
    if (DashboardCache.isFresh()) {
      _lat = DashboardCache.lat;
      _lon = DashboardCache.lon;
      _locationLabel = DashboardCache.locationLabel ?? _locationLabel;
      _airAddr = DashboardCache.airAddr ?? _airAddr;
      _rebuildNearbyIssuesStream();
      _future = Future.value(DashboardCache.data!);
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

  Future<void> _loadOrderFromDb() async {
    final uid = _uid;
    if (uid == null) return;
    final loaded = await _settingsStore.loadHomeCardOrder(uid);
    if (!mounted) return;
    setState(() => _order = loaded);
  }

  void _toggleEditMode() async {

    setState(() => _editMode = true);

    await _openOrderSheet();

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
    final uid = _uid;
    if (uid == null) return;
    await _settingsStore.saveHomeCardOrder(uid, _order);

    // await HomeCardOrderStore.save(_order);

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

  String pickDisplayLabel(List<Placemark> pms) {
    String clean(String? s) =>
        _t(s).replaceAll(RegExp(r'[^0-9A-Za-z가-힣\s]'), ' ').trim();

    bool ok(String s) => s.isNotEmpty && !_looksLikeOnlyNumberOrLot(s);

    // 1) 역 토큰(있으면 표시용으로만 보관)
    String? station;
    for (final p in pms) {
      final blob = [
        clean(p.name),
        clean(p.thoroughfare),
        clean(p.subLocality),
        clean(p.locality),
        clean(p.subAdministrativeArea),
        clean(p.administrativeArea),
      ].where((e) => e.isNotEmpty).join(' ');

      for (final w0 in blob.split(RegExp(r'\s+'))) {
        final w = w0.replaceAll(RegExp(r'[^0-9A-Za-z가-힣]'), '');
        if (!ok(w)) continue;
        if (w.endsWith('역') && w != '광역') {
          station = w;
          break;
        }
      }
      if (station != null) break;
    }

    // 2) 구/군/시 + 동/읍/면/리 뽑기 (✅ subLocality, thoroughfare까지 포함!)
    String? guGunSi;
    String? dongEupMyeon;

    for (final p in pms) {
      final candidates = <String>[
        clean(p.subAdministrativeArea),
        clean(p.subLocality),      // ✅ 여기서 "부평구"가 들어오는 케이스 있음
        clean(p.locality),
        clean(p.thoroughfare),     // ✅ 여기서 "부평동"이 들어오는 케이스 있음
        clean(p.name),
        clean(p.administrativeArea),
      ].where(ok).toList();

      // 구/군 우선, 없으면 시
      guGunSi ??= candidates.firstWhere(
            (s) => s.endsWith('구') || s.endsWith('군'),
        orElse: () => '',
      );
      if (guGunSi!.isEmpty) {
        final si = candidates.firstWhere((s) => s.endsWith('시'), orElse: () => '');
        if (si.isNotEmpty) guGunSi = si;
      }
      if (guGunSi!.isEmpty) guGunSi = null;

      // 동/읍/면/리
      dongEupMyeon ??= candidates.firstWhere(
            (s) => s.endsWith('동') || s.endsWith('읍') || s.endsWith('면') || s.endsWith('리'),
        orElse: () => '',
      );
      if (dongEupMyeon!.isEmpty) dongEupMyeon = null;

      if (guGunSi != null && dongEupMyeon != null) break;
    }

    final areaParts = <String>[
      if (guGunSi != null) guGunSi!,
      if (dongEupMyeon != null && dongEupMyeon != guGunSi) dongEupMyeon!,
    ];

    final areaText = areaParts.isNotEmpty
        ? areaParts.join(' ')
        : (pms.isNotEmpty ? clean(pms.first.administrativeArea) : '현재 위치');

    if (station != null && station!.isNotEmpty) {
      return '$station · $areaText';
    }
    return areaText.isNotEmpty ? areaText : '현재 위치';
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

  String _pickNotiArea(String label) {
    final parts = label.split('·').map((e) => e.trim()).toList();
    // "부평역 · 부평구 부평동" -> "부평구 부평동"
    if (parts.length >= 2) return parts.last;
    return label.trim(); // 이미 "부평구 부평동"이면 그대로
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

    _rebuildNearbyIssuesStream();
    if (mounted) setState(() {});

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
      final placemarks = await _safePlacemarks();
      adminArea = placemarks.isNotEmpty ? (placemarks.first.administrativeArea ?? '').trim() : '';
      label = pickDisplayLabel(placemarks);
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
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final notiArea = _pickNotiArea(label); // label은 지역변수로 쓰고 있지
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'lastLocation': {'latitude': _lat, 'longitude': _lon},
        'locationName': label,               // 표시용(역 포함 가능)
        'notiArea': notiArea,                // ✅ 알림용(구 동)
        'addr': addr,                        // airAddr (인천광역시 부평구)
        'administrativeArea': adminArea,     // 인천광역시
        'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

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

  Future<List<Placemark>> _safePlacemarks() async {
    final lat = _lat;
    final lon = _lon;
    if (lat == null || lon == null) return <Placemark>[];

    return placemarkFromCoordinates(lat, lon)
        .timeout(const Duration(seconds: 2), onTimeout: () => <Placemark>[]);
  }

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 0,
      body: FutureBuilder<DashboardData>(
        future: _future,
        initialData: DashboardCache.data,
        builder: (context, snapshot) {
          final data = snapshot.data ?? DashboardCache.data;

          final isFirstLoading = (data == null);
          final isRefreshing = _isRefreshing;

          if (snapshot.hasError && data == null) {
            final err = snapshot.error;
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 36),
                    const SizedBox(height: 12),
                    Text('데이터 로드 실패\n$err', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _reload, child: const Text('다시시도')),
                  ],
                ),
              ),
            );
          }

          final now = data?.now;
          final safeData = data;
          final updatedAt = safeData?.updatedAt ?? DateTime.now();
          final user = FirebaseAuth.instance.currentUser;
          final userStream = (user == null)
              ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
              : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

          final hasCoord = _lat != null && _lon != null;

          return Scaffold(
            key: _scaffoldkey,

            drawer: (user == null)
                ? null
                : (hasCoord
                ? AppDrawerFactory.buildWithNearbyMap(
              context: context,
              userStream: userStream,
              locationLabel: _locationLabel,

              // ✅ 홈에서는 "홈/닫기"가 뜨는 쪽
              isHome: true,
              onGoHome: () {},

              myLat: _lat!, // ✅ hasCoord라 안전
              myLng: _lon!, // ✅ hasCoord라 안전
              getNearbyTopPosts: () async => _nearbyIssuesLatest3,
              // background: ... (원하면)
            )
                : AppDrawerFactory.buildBasic(
              context: context,
              userStream: userStream,
              locationLabel: _locationLabel,

              // ✅ 홈에서는 "홈/닫기"가 뜨는 쪽
              isHome: true,
              onGoHome: () {},

              // ✅ 위치 없을 때 '내 주변 지도' 눌러도 크래시 안 나게
              onGoNearbyMapOverride: () {
                Navigator.pop(context); // drawer 닫기
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('위치를 불러오는 중입니다. 잠시 후 다시 시도해주세요.')),
                );
              },
            )),

            body: Stack(
              children: [
                WeatherBackground(now: now, lat: _lat, lon: _lon),
                if (now != null) PrecipitationLayer(now: now),

                SafeArea(
                  child: RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 16, 12),
                            child: _TopBar(
                              onOpenMenu: () => _scaffoldkey.currentState?.openDrawer(),
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
                                  key: ValueKey('home-card-${id.name}'),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildHomeCard(id, safeData, isFirstLoading),
                                );
                              },
                              childCount: _order.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}