import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/dashboard_service.dart';
import '../data/models.dart';
// 2025-12-23 jgh251223---S
import '../data/transit_service.dart';
// 2025-12-23 jgh251223---E
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 2025-12-23 jgh251223---S
// 2025-12-23 jgh251223---E
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../tmaprouteview/routeview.dart'; //jgh251224

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DashboardService _service;
  // 2025-12-23 jgh251223---S
  late final TransitService _transitService;
  Future<TransitRouteResult>? _transitFuture;
  // 2025-12-23 jgh251223---E
  Future<DashboardData>? _future;

  // TODO: GPS/행정동 매핑 붙이면 여기 값이 동적으로 바뀜
  double? _lat;
  double? _lon;
  String _locationLabel = '위치 확인 중...'; // 화면 표시용 (부평역)
  String _airAddr = '';                      // 에어코리아 검색용 (인천광역시 부평구)

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
    // 2025-12-23 jgh251223---S
    final apiKey = dotenv.env['TMAP_API_KEY'] ??
        const String.fromEnvironment('TMAP_API_KEY', defaultValue: '');
    _transitService = TransitService(
      apiKey: apiKey,
      destination: _defaultDestination,
    );
    // 2025-12-23 jgh251223---E
    _future = _initLocationAndFetch();
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


  Future<DashboardData> _initLocationAndFetch() async {
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
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _lat = pos.latitude;
    _lon = pos.longitude;

    // 역지오코딩(동 이름/구 이름)
    final placemarks = await placemarkFromCoordinates(_lat!, _lon!);

    final label = pickDisplayLabel(placemarks); // ✅ 부평역/부산역/속초역 같은 표시용
    final addr = pickAirAddr(placemarks);       // ✅ 인천광역시 부평구 같은 대기질용

    setState(() {
      _locationLabel = label;
      _airAddr = addr;
      // _locationName = [admin, locality, _umdName].where((e) => e.isNotEmpty).join(' ');
      // 2025-12-23 jgh251223---S
      _transitFuture = _transitService.fetchRoute(
        startLat: _lat!,
        startLon: _lon!,
        startName: _locationLabel,
      );
      // 2025-12-23 jgh251223---E
    });

    // ✅ Functions 호출 (lat/lon/umdName)
    return _service.fetchDashboardByLatLon(
      lat: _lat!,
      lon: _lon!,
      locationName: _locationLabel,
      airAddr: _airAddr, administrativeArea: ''
    );
  }

  void _reload() {
    setState(() {
      _future = _initLocationAndFetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1E88E5);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            // ✅ 에러 먼저 처리 (여기서 data! 쓰면 안 됨)
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '데이터 로드 실패:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final data = snapshot.data;

            // ✅ 로딩 조건 강화: done이 아니거나 data가 없으면 로딩
            final isLoading =
                snapshot.connectionState != ConnectionState.done || data == null;

            return RefreshIndicator(
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

                  if (!isLoading && data!.alerts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _AlertBanner(alert: data.alerts.first),
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        _Card(
                          child: isLoading
                              ? const _Skeleton(height: 120)
                              : _WeatherHero(now: data!.now),
                        ),
                        const SizedBox(height: 12),

                        _Card(
                          child: isLoading
                              ? const _Skeleton(height: 90)
                              : _RainCard(now: data!.now),
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
                      ]),
                    ),
                  ),
                ],
              ),
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
  const _WeatherHero({required this.now});
  final WeatherNow now;

  @override
  Widget build(BuildContext context) {
    final temp = now.temp?.round();
    final feel = (now.temp != null && now.wind != null)
        ? (now.temp! - (now.wind! * 0.7)).round() // 아주 단순한 체감(대충)
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _WeatherIcon(sky: now.sky, pty: now.pty, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${temp ?? '--'}°',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '체감 ${feel ?? '--'}°  ·  습도 ${now.humidity?.round() ?? '--'}%  ·  바람 ${now.wind?.toStringAsFixed(1) ?? '--'}m/s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RainCard extends StatelessWidget {
  const _RainCard({required this.now});
  final WeatherNow now;

  @override
  Widget build(BuildContext context) {
    final pty = now.pty ?? 0;
    final isRainOrSnow = pty != 0;
    final label = switch (pty) {
      1 => '비',
      2 => '비/눈',
      3 => '눈',
      4 => '소나기',
      _ => '강수 없음',
    };

    final rn1 = now.rn1;
    final sub = (rn1 == null)
        ? '강수량 정보 없음'
        : (rn1 <= 0 ? '최근 1시간 강수 0mm' : '최근 1시간 강수 ${rn1.toStringAsFixed(1)}mm');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(isRainOrSnow ? Icons.umbrella : Icons.wb_sunny, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
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

  @override
  Widget build(BuildContext context) {
    final maskHint = (air.gradeText.contains('나쁨')) ? '마스크 권장' : '마스크 선택';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.masks, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '대기질 ${air.gradeText}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PM10 ${air.pm10 ?? '--'} · PM2.5 ${air.pm25 ?? '--'}  ·  $maskHint',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
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

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alert});
  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${alert.title}${alert.region == null ? '' : ' · ${alert.region}'}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  // 경로 눈으로 보기
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Routeview(raw: data.raw),

                    ),
                  );
                },
                child: const Text('[경로 보기]'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  // TODO: 즐겨찾기 저장/삭제 로직 연결
                },
                child: const Text('[즐겨찾기]'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// 2025-12-23 jgh251223---E
