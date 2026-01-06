import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/community/CommunityView.dart';
import 'package:flutter_project/data/favorite_route.dart';
import 'package:flutter_project/home/ui_helpers.dart';
import 'package:flutter_project/utils/launcher.dart';
import 'package:intl/intl.dart';
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
import 'home_card_order.dart'; //jgh251226


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
  Future<List<NearbyIssuePost>>? _nearbyIssuesFuture;

  Future<void> _openForecastWeb() async {
    if (_lat == null || _lon == null) return;

    await openWeatherNuri(
      lat: _lat!,
      lon: _lon!,
      code: _weatherNuriCode, // String? 멤버로 존재해야 함
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
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '교통 정보를 불러오지 못했습니다.\n${transitSnap.error}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          // ✅ 에러 상태에서도 즐겨찾기 관리/추가로 바로 이동 가능하게
                          OutlinedButton.icon(
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('즐겨찾기 관리'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.45)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
            future: _nearbyIssuesFuture ?? Future.value(const []),
            onOpenPost: (docId) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Communityview(docId: docId),
                ),
              );
            },
            onMapPressed: () async {
              // 1) Future에서 가져온 최신 3개를 같이 넘겨야 함
              final posts = await (_nearbyIssuesFuture ?? Future.value(const <NearbyIssuePost>[]));

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NearbyIssuesMapPage(
                    myLat: _lat!,
                    myLng: _lon!,
                    posts: posts,
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
    _settingsStore = UserSettingsStore();
    _loadOrderFromDb();

    final uid = _uid;
    if (uid == null) return;
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
      // ✅ 위치 라벨도 즉시 복원(화면 상단 빨리 뜸)
      _lat = DashboardCache.lat;
      _lon = DashboardCache.lon;
      _locationLabel = DashboardCache.locationLabel ?? _locationLabel;
      _airAddr = DashboardCache.airAddr ?? _airAddr;
      _future = Future.value(DashboardCache.data!);
      // _refreshInBackground();
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

    _nearbyIssuesFuture = _nearbyIssuesService.fetchNearbyIssueTop3(
      myLat: _lat!,
      myLng: _lon!,
    );

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

  bool _isNightFallback(DateTime nowLocal) {
    final h = nowLocal.hour;
    return !(h >= 6 && h < 18);
  }

  // ✅ isUtc 플래그를 “제거”하고 벽시계 시간만 살림
  DateTime _asWallLocal(DateTime dt) {
    return DateTime(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }

  bool _isNightBySun(double lat, double lon) {
    final nowLocal = DateTime.now(); // ✅ 그냥 로컬로
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    final ss = getSunriseSunset(lat, lon, nowLocal.timeZoneOffset, todayLocal);

    // ✅ 여기 핵심: 오프셋 더하지 말고 “벽시계”로만 사용
    final sunrise = _asWallLocal(ss.sunrise);
    var sunset = _asWallLocal(ss.sunset);

    // 혹시 sunset이 sunrise보다 이르면(드물게) 다음날로 보정
    if (sunset.isBefore(sunrise)) {
      sunset = sunset.add(const Duration(days: 1));
    }

    // ✅ sanity check(이상하면 fallback)
    final valid = sunset.isAfter(sunrise) &&
        sunset.difference(sunrise).inHours >= 6 &&
        sunrise.hour < 12; // 일출이 오후면 뭔가 꼬인 것

    final night = valid
        ? (nowLocal.isBefore(sunrise) || nowLocal.isAfter(sunset))
        : _isNightFallback(nowLocal);

    if (kDebugMode) {
      debugPrint(
        '[WB] nowLocal=$nowLocal '
            'rawUtc(sunrise/sunset)=${ss.sunrise.isUtc}/${ss.sunset.isUtc} '
            'sunrise=$sunrise sunset=$sunset valid=$valid night=$night',
      );
    }
    return night;
  }

  @override
  Widget build(BuildContext context) {
    final hasCoord = lat != null && lon != null;
    final night = hasCoord
        ? _isNightBySun(lat!, lon!)
        : _isNightFallback(DateTime.now());

    final sky = now?.sky ?? 3;
    final pty = now?.pty ?? 0;

    List<Color> colors = night
        ? [const Color(0xFF0B1026), const Color(0xFF1A2A5A)]
        : [const Color(0xFF4FC3F7), const Color(0xFF1976D2)];

    if (sky >= 4) {
      colors = night
          ? [const Color(0xFF0B1026), const Color(0xFF2B2F3A)]
          : [const Color(0xFF90A4AE), const Color(0xFF546E7A)];
    } else if (sky == 3) {
      colors = night
          ? [const Color(0xFF0B1026), const Color(0xFF26324A)]
          : [const Color(0xFF81D4FA), const Color(0xFF455A64)];
    }

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
    this.todayMax,
    this.todayMin,
  });

  final WeatherNow now;
  final DateTime? sunrise;
  final DateTime? sunset;

  final double? todayMax;
  final double? todayMin;

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

    final maxT = todayMax?.round();
    final minT = todayMin?.round();

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
                    const SizedBox(width: 14),
                    Flexible( // ✅ 핵심: 공간 부족하면 줄어들 수 있게
                      fit: FlexFit.loose,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘',
                            style: t.labelSmall?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox( // ✅ 한 줄 유지 + 필요시 축소
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '↑${maxT ?? '--'}°',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '↓${minT ?? '--'}°',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white70,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                  width: 92,
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
                      // ✅ 최고/최저 온도 (줄바꿈 방지)
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 14, // 카드들 높이 들쭉날쭉 방지(선택)
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                              children: [
                                TextSpan(text: '↑$maxText°  ', style: const TextStyle(color: Colors.white)),
                                TextSpan(text: '↓$minText°', style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center,
                          ),
                        ),
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
    final mainTitle = prettyAlertTitle(first.title);
    final more = alerts.length - 1;
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
                  Text(
                    '기상 특보',
                    style: t.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ✅ 1) 메인 특보명(짧게)
                  Text(
                    mainTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  // ✅ 2) 외 n건 + 발표시각
                  const SizedBox(height: 4),
                  Text(
                    '${more > 0 ? '외 ${more}건 · ' : ''}발표 ${_prettyTime(first.timeText)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: Colors.white70),
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

  String _prettyTitle(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'^\[특보\]\s*'), '');
    s = s.replaceAll(RegExp(r'^제\d+[-–]\d+호\s*:\s*'), '');
    s = s.replaceAll(RegExp(r'^\d{4}\.\d{2}\.\d{2}\.\d{2}:\d{2}\s*/\s*'), '');
    s = s.replaceAll(RegExp(r'\s*발표\s*\(\*\)\s*'), '');
    s = s.replaceAll(RegExp(r'\(\*\)\s*'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? raw : s;
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
                Text(
                  _prettyTitle(a.title),
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('발표: ${_prettyTime(a.timeText)}', style: t.bodySmall),

                // (선택) 원문도 보고 싶으면 주석 해제
                // const SizedBox(height: 6),
                // Text(a.title, style: t.bodySmall?.copyWith(color: Colors.white70)),

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

String prettyAlertTitle(String raw) {
  var s = raw.trim();

  // 예: "[특보]" 제거
  s = s.replaceAll(RegExp(r'^\[특보\]\s*'), '');

  // 예: "제12-85호 :" 같은 번호 제거
  s = s.replaceAll(RegExp(r'^제\d+[-–]\d+호\s*:\s*'), '');

  // 예: "2025.12.31.17:01 / " 같은 날짜/슬래시 제거
  s = s.replaceAll(RegExp(r'^\d{4}\.\d{2}\.\d{2}\.\d{2}:\d{2}\s*/\s*'), '');

  // 예: "발표(*)" / "발표 (*)" / "(*)" 정리
  s = s.replaceAll(RegExp(r'\s*발표\s*\(\*\)\s*'), '');
  s = s.replaceAll(RegExp(r'\(\*\)\s*'), '');

  // 남는 앞/뒤 공백, 기호 정리
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  return s.isEmpty ? raw : s;
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
  // ===== (B) 버스 15초 폴링 =====
  Timer? _busTimer;
  bool _busInFlight = false;

  Future<String?>? _busFuture;
  DateTime? _busUpdatedAt;

  final Map<String, TagoStop> _stopCache = {};
  final Map<String, DateTime> _stopCacheAt = {};

  double? _toDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v');

  _BusLegInfo? _firstBusLegInfoFromRaw(TransitVariant v) {
  final raw = widget.data.raw;
  if (raw.isEmpty) return null;

  final meta = (raw['metaData'] ?? raw['meta']) as Map? ?? {};
  final plan = (meta['plan'] ?? {}) as Map? ?? {};
  final itins = (plan['itineraries'] ?? []) as List? ?? const [];
  if (itins.isEmpty) return null;

  final idx = widget.data.indexOf(v);
  if (idx < 0 || idx >= itins.length) return null;

  final it = Map<String, dynamic>.from(itins[idx] as Map);
  final legs = (it['legs'] ?? const []) as List;

  for (final e in legs) {
  final leg = Map<String, dynamic>.from(e as Map);
  final mode = (leg['mode'] ?? '').toString().toUpperCase();
  if (mode != 'BUS') continue;

  // 노선 문자열
  final rawRoute = (leg['route'] ?? leg['routeName'] ?? leg['lineName'] ?? '').toString();
  final token = extractRouteToken(rawRoute);
  if (token == null) continue;
  final routeNo = _normRouteNo(token);
  if (routeNo.isEmpty) continue;

  // 승차 정류장 좌표 (start)
  final start = (leg['start'] is Map) ? Map<String, dynamic>.from(leg['start'] as Map) : <String, dynamic>{};

  final lat = _toDouble(start['lat'] ?? start['startY'] ?? start['y']);
  final lon = _toDouble(start['lon'] ?? start['lng'] ?? start['startX'] ?? start['x']);
  if (lat == null || lon == null) continue;

  return _BusLegInfo(routeNo: routeNo, lat: lat, lon: lon);
  }

  return null;
  }

  String? extractRouteToken(String s) {
    final cleaned = s
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('번', '')
        .toUpperCase();

    // ✅ 숫자가 1개 이상 포함된 연속 토큰(예: 1400, 1400-1, M6450, N26)
    final m = RegExp(r'([0-9A-Z-]*\d[0-9A-Z-]*)').firstMatch(cleaned);
    return m?.group(1);
  }

  String _normRouteNo(String s) => s
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('번', '')
      .toUpperCase()
      .replaceAll(RegExp(r'[^0-9A-Z-]'), ''); // ✅ 한글 제거

  String _stopKey(double lat, double lon, String routeNo) =>
      '${_normRouteNo(routeNo)}@${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // ✅ 1) 즐겨찾기별 variant 복원
    await _loadVariant();

    // ✅ 2) 버스 폴링 시작
    _startBusPolling();
  }

  @override
  void didUpdateWidget(covariant _TransitCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ 즐겨찾기 바뀌면: 저장된 variant 다시 로드 + 폴링 리셋
    if (oldWidget.favoriteId != widget.favoriteId) {
      if (widget.favoriteId == null || widget.favoriteId!.isEmpty) {
        setState(() => _selected = TransitVariant.fastest);
        _resetBusPolling();
      } else {
        _loadVariant().then((_) => _resetBusPolling());
      }
    }

    // ✅ 위치가 바뀌면 정류장 캐시 무효화(원치 않으면 삭제 가능)
    if (oldWidget.startLat != widget.startLat || oldWidget.startLon != widget.startLon) {
      _invalidateStopCache();
    }
  }

  @override
  void dispose() {
    _busTimer?.cancel();
    super.dispose();
  }

  void _startBusPolling() {
    _busTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBusArrivalNow(); // ✅ 첫 프레임 이후
    });

    _busTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshBusArrivalNow();
    });
  }

  void _resetBusPolling() {
    _invalidateStopCache();
    _startBusPolling();
  }

  void _invalidateStopCache() {
    _stopCache.clear();
    _stopCacheAt.clear();
  }

  void _refreshBusArrivalNow() {
    if (_busInFlight) return;
    _busInFlight = true;

    final fut = _fetchBusArrivalForVariant(_selected).catchError((e) {
      debugPrint('[BUS] _fetch error=$e');
      return null;
    });

    if (mounted) {
      setState(() {
        _busFuture = fut; // ✅ FutureBuilder가 새 Future를 보게 됨
      });
    }

    fut.then((_) {
      _busUpdatedAt = DateTime.now();
    }).whenComplete(() {
      _busInFlight = false;
      if (mounted) setState(() {});
    });
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

    // ✅ 여기서 "routeNo가 실제로 뜨는 정류장"을 찾는다
    for (final st in stops) {
      try {
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
      } catch (e) {
        // 여기까지 오면 service가 throw한건데, 위 1번을 하면 사실상 안 옴
        debugPrint('[BUS] arrival error stop=${st.nodeId} e=$e');
      }
    }

    return null;
  }

  String? _extractRouteNo(String text) {
    return extractRouteToken(text); // ✅ 너가 만든 함수 그대로 사용
  }

  bool _hasBusLeg(TransitVariant v) {
    final raw = widget.data.raw;
    if (raw.isEmpty) return false;

    final meta = (raw['metaData'] ?? raw['meta']) as Map? ?? {};
    final plan = (meta['plan'] ?? {}) as Map? ?? {};
    final itins = (plan['itineraries'] ?? []) as List? ?? const [];
    if (itins.isEmpty) return false;

    final idx = widget.data.indexOf(v);
    if (idx < 0 || idx >= itins.length) return false;

    final it = Map<String, dynamic>.from(itins[idx] as Map);
    final legs = (it['legs'] ?? const []) as List;

    for (final e in legs) {
      final leg = Map<String, dynamic>.from(e as Map);
      final mode = (leg['mode'] ?? '').toString().toUpperCase();
      if (mode == 'BUS') return true;
    }
    return false;
  }

  Future<String?> _fetchBusArrivalForVariant(TransitVariant v) async {
    
    if (!_hasBusLeg(v)) return null;
    // ✅ 1) raw에서 "버스 승차정류장 좌표 + 노선" 우선 추출
    final info = _firstBusLegInfoFromRaw(v);

    // ✅ 2) 좌표/노선 fallback: raw에서 못 뽑으면 기존 방식(즐겨찾기 start/텍스트) 사용
    final lat = info?.lat ?? widget.startLat;
    final lon = info?.lon ?? widget.startLon;
    if (lat == 0.0 || lon == 0.0) return null;

    final s = widget.data.summaryOf(v);

    final routeNo = info?.routeNo ??
        _normRouteNo(
          (_extractRouteNo(s.firstArrivalText) ?? _extractRouteNo(s.secondArrivalText)) ?? '',
        );

    if (routeNo.isEmpty) return '버스 노선번호 추출 실패';
    debugPrint('[BUS] v=$v route=$routeNo lat=$lat lon=$lon rawInfo=${info != null}');

    // ✅ 3) routeNo가 실제로 뜨는 정류장 찾기(주변 8개 탐색)
    final stop = await _ensureStopForRoute(lat: lat, lon: lon, routeNo: routeNo);
    if (stop == null) return null;

    // ✅ 4) 도착정보 조회
    return widget.busArrivalService.fetchNextArrivalText(
      cityCode: stop.cityCode,
      nodeId: stop.nodeId,
      routeNo: routeNo,
    );
  }

  List<_LegUiStep> _buildLegSteps(TransitVariant v) {
    final s = widget.data.summaryOf(v);

    final legs = <String>[
      s.firstArrivalText.trim(),
      s.secondArrivalText.trim(),
    ].where((e) => e.isNotEmpty).toList();

    IconData iconFromLeg(String t) {
      final up = t.toUpperCase();
      if (t.contains('버스') || up.contains('BUS')) return Icons.directions_bus;
      if (t.contains('지하철') || up.contains('SUBWAY') || up.contains('METRO')) return Icons.subway;
      return Icons.directions_walk;
    }

    String labelFromLeg(String t) {
      // 너무 길면 flowRow에서 maxLines 2로 잘릴 거라 일단 그대로
      return t.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final out = <_LegUiStep>[];

    // 시작/도착 노드
    out.add(_LegUiStep(Icons.my_location, '출발'));

    for (final t in legs) {
      out.add(_LegUiStep(iconFromLeg(t), labelFromLeg(t)));
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
            SizedBox(
              width: 84,
              child: Text(
                s.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ],
        );
      }

      Widget arrow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
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
    final arrivalText = [s.firstArrivalText, s.secondArrivalText]
        .where((e) => e.isNotEmpty)
        .join(' / ');

    ChoiceChip chip(String label, TransitVariant v) {
      return ChoiceChip(
        label: Text(label),
        selected: _selected == v,
        onSelected: (_) async {
          setState(() => _selected = v);
          _saveVariant(v);
          _refreshBusArrivalNow();
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
          Text(s.summary, style: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(arrivalText.isEmpty ? '도착 정보 없음' : arrivalText,
              style: textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
          // ✅ 실시간 버스 도착정보(추가)
          FutureBuilder<String?>(
            future: _busFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '버스 도착정보 불러오는 중…',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              final live = snap.data?.trim() ?? '';

              if (live.isEmpty) {
                if (!_hasBusLeg(_selected)) {
                  return const SizedBox.shrink();
                }
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_busUpdatedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '업데이트: ${_hhmmss(_busUpdatedAt!)}',
                          style: textTheme.labelSmall?.copyWith(color: Colors.white54),
                        )
                      ),
                  ],
                )
              );
            },
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
                        initialItineraryIndex: widget.data.indexOf(_selected), // ✅ 추가
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  widget.onFavoritePressed?.call();
                },
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

// ChecklistItem, DashboardData 타입은 너 프로젝트에 이미 있는 걸 사용
class _CarryCardFromFirestore extends StatefulWidget {
  const _CarryCardFromFirestore({required this.items, required this.data});

  final List<ChecklistItem> items;
  final DashboardData data;

  @override
  State<_CarryCardFromFirestore> createState() => _CarryCardFromFirestoreState();
}

class _CarryCardFromFirestoreState extends State<_CarryCardFromFirestore> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  String get _prefKey => 'carry_enabled_$_uid'; // ✅ 유저별 로컬 키
  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      FirebaseFirestore.instance.collection('user_settings').doc(_uid);
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _loadPref();
    _loadRemote();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_prefKey);
    if (!mounted) return;
    setState(() {
      _enabled = v ?? true; // 기본 ON
    });
  }

  Future<void> _loadRemote() async {
    // 로그인 전이면 스킵
    if (_uid == 'anon') return;

    try {
      final snap = await _settingsDoc.get();
      final data = snap.data();
      final v = data?['carryEnabled'];

      if (!mounted) return;
      if (v is bool) {
        setState(() => _enabled = v);

        // 원격값을 로컬에도 캐시
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKey, v);
      }
    } catch (_) {
      // 네트워크 실패 시 로컬값 유지
    }
  }

  Future<void> _setEnabled(bool v) async {
    setState(() => _enabled = v); // ✅ 즉시 반영
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, v); // ✅ 로컬 저장

    if (_uid == 'anon') return;
    // firestore 저장
    await _settingsDoc.set(
      {'carryEnabled': v},
      SetOptions(merge: true),
    );
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

class _NearbyIssuesCard extends StatelessWidget {
  const _NearbyIssuesCard({
    required this.future,
    required this.onMapPressed,
    required this.onReportPressed,
    required this.onOpenPost,
    required this.onAddPressed,
  });

  final Future<List<NearbyIssuePost>> future;
  final VoidCallback onMapPressed;
  final VoidCallback onReportPressed;
  final ValueChanged<String> onOpenPost;
  final VoidCallback onAddPressed;

  String _prettyTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';

    // 24시간 넘으면 MM/dd
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$mm/$dd';
  }

  Widget _metaChip(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return FutureBuilder<List<NearbyIssuePost>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // 너 프로젝트의 스켈레톤 컴포넌트 있으면 그걸로 교체
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
          );
        }

        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '내 주변 글을 불러오지 못했습니다.\n${snap.error}',
              style: t.bodySmall?.copyWith(color: Colors.white70),
            ),
          );
        }

        final issues = snap.data ?? const [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '내 주변 1km 사건/이슈',
                      style: t.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '사건/이슈 글 쓰기',
                    onPressed: onAddPressed,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '최신 3건',
                style: t.labelMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              if (issues.isEmpty)
                Text('1km 내 사건/이슈 글이 없습니다.',
                    style: t.bodySmall?.copyWith(color: Colors.white70))
              else
                for (final p in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onOpenPost(p.id), // ✅ docId 전달
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    children: [
                                      _metaChip('약 ${p.distanceMeters}m', Icons.place_outlined),
                                      _metaChip('${p.likeCount}', Icons.favorite_border),
                                      _metaChip('${p.commentCount}', Icons.chat_bubble_outline),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _prettyTime(p.createdAt),
                              style: t.labelSmall?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onMapPressed,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('지도 보기'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onReportPressed,
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: const Text('제보'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
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