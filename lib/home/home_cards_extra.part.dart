part of 'home_page.dart';

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
    required this.stream,
    required this.onMapPressed,
    required this.onReportPressed,
    required this.onOpenPost,
    required this.onAddPressed,
    this.onData,
  });

  final Stream<List<NearbyIssuePost>> stream;

  final VoidCallback onMapPressed;
  final VoidCallback onReportPressed;
  final ValueChanged<String> onOpenPost;
  final VoidCallback onAddPressed;

  /// ✅ 최신 3개를 Home(State) 쪽으로 올려보내기 위한 콜백
  final ValueChanged<List<NearbyIssuePost>>? onData;

  String _prettyTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';

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

    return StreamBuilder<List<NearbyIssuePost>>(
      stream: stream,
      builder: (context, snap) {
        // 로딩
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
          );
        }

        // 에러
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '내 주변 글을 불러오지 못했습니다.\n${snap.error}',
              style: t.bodySmall?.copyWith(color: Colors.white70),
            ),
          );
        }

        final issues = snap.data ?? const <NearbyIssuePost>[];

        // ✅ Home으로 최신 리스트 전달 (무한 rebuild 안전하게 post-frame)
        if (onData != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onData!.call(issues);
          });
        }

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
                Text(
                  '1km 내 사건/이슈 글이 없습니다.',
                  style: t.bodySmall?.copyWith(color: Colors.white70),
                )
              else
                for (final p in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onOpenPost(p.id),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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