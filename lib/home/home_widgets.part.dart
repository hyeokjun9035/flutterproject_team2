part of 'home_page.dart';

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