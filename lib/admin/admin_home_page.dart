import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_board_title/title_list_page.dart';
import 'postDetailPage.dart';
import 'notices/notice_create_page.dart';
import 'admin_alarm_page.dart'; // ✅ 파일명 변경 반영 (alarm 포함)
import 'package:flutter_project/admin/admin_report_detail_page.dart';
import 'data/notice_repository.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<_AdminDashboardPageState> _dashboardKey =
      GlobalKey<_AdminDashboardPageState>();
  int _currentIndex = 0;

  String _reportFilter = 'open';

  void _goToReportTab() {
    setState(() {
      _reportFilter = 'open'; // ✅ 미처리로 고정
      _currentIndex = 2; // ✅ 신고 탭으로 이동
    });
  }

  void _goToClosedReportTab() {
    setState(() {
      _reportFilter = 'closed'; // ✅ 처리완료
      _currentIndex = 2; // ✅ 신고 탭
    });
  }

  bool _showBlockedOnly = false;

  void _goToUsersTab({bool blockedOnly = false}) {
    setState(() {
      _showBlockedOnly = blockedOnly;
      _currentIndex = 3; // 사용자들 탭
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminDashboardPage(
        key: _dashboardKey,
        onGoReport: _goToReportTab, // ✅ 여기 연결
        onGoClosedReport: _goToClosedReportTab,
        onGoPosts: () => setState(() => _currentIndex = 1),
        onGoUsers: () => _goToUsersTab(blockedOnly: false),
        onGoBlockedUsers: () => _goToUsersTab(blockedOnly: true),
      ),
      const _AdminPostListPage(),
      _AdminReportPage(initialFilter: _reportFilter), // ✅ 여기!
      _AdminUsersPage(blockedOnly: _showBlockedOnly),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 페이지'),
        // backgroundColor: Colors.black,
        backgroundColor: const Color(0xFF1A237E), // 👈 딥 네이비로 변경
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '공지 관리',
            icon: const Icon(Icons.campaign),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TitleListPage()),
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_currentIndex == 0) _dashboardKey.currentState?.reload();
            },
          ),
          IconButton(
            tooltip: '알림 발송(Alarm)',
            icon: const Icon(Icons.notifications_active),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminAlarmPage()),
            ),
          ),
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
              if (ok == true)
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        // selectedItemColor: Colors.black,
        selectedItemColor: const Color(0xFF1A237E), // 👈 강조색 변경
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: '대시보드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: '게시글',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_gmailerrorred_outlined),
            label: '신고',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: '사용자들',
          ),
        ],
      ),
    );
  }
}

/* -------------------- 1) 대시보드 -------------------- */
class _AdminDashboardPage extends StatefulWidget {
  final VoidCallback onGoReport;
  final VoidCallback onGoClosedReport;
  final VoidCallback onGoPosts;
  final VoidCallback onGoUsers;
  final VoidCallback onGoBlockedUsers;

  const _AdminDashboardPage({
    super.key,
    required this.onGoReport,
    required this.onGoClosedReport,
    required this.onGoPosts,
    required this.onGoUsers,
    required this.onGoBlockedUsers,
  });
  @override
  State<_AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<_AdminDashboardPage> {
  final repo = NoticeRepository();

  int todayPostCount = 0;
  int totalUserCount = 0;
  bool loadingUsers = true;
  int todayReportCount = 0;
  int openReportCount = 0;
  int closedReportCount = 0;
  int blockedUserCount = 0;
  bool loadingReports = true;

  bool loading = true;

  List<int> weeklyCounts = [0, 0, 0, 0, 0, 0, 0];
  Map<String, int> categoryCounts = {};
  int totalMediaPosts = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayPostCount();
    _loadReportCounts();
    _loadBlockedUserCount();
    reload();
  }

  Future<void> _loadTodayReportCount() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfDay.add(const Duration(days: 1));

      final qs = await FirebaseFirestore.instance
          .collection('reports')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(startOfTomorrow))
          .count()
          .get();

      if (!mounted) return;
      setState(() => todayReportCount = qs.count ?? 0);
    } catch (e) {
      debugPrint('todayReportCount error: $e');
      if (!mounted) return;
      setState(() => todayReportCount = 0);
    }
  }

  Future<void> _loadOpenReportCount() async {
    try {
      final qs = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'open')
          .count()
          .get();

      if (!mounted) return;
      setState(() => openReportCount = qs.count ?? 0);
    } catch (e) {
      debugPrint('openReportCount error: $e');
      if (!mounted) return;
      setState(() => openReportCount = 0);
    }
  }

  Future<void> _loadBlockedUserCount() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .where('writeBlockedUntil', isGreaterThan: now)
          .count()
          .get();

      if (!mounted) return;
      setState(() => blockedUserCount = qs.count ?? 0);
    } catch (e) {
      debugPrint('blockedUserCount error: $e');
      if (!mounted) return;
      setState(() => blockedUserCount = 0);
    }
  }

  Future<void> _loadClosedReportCount() async {
    try {
      final qs = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'closed')
          .count()
          .get();

      if (!mounted) return;
      setState(() => closedReportCount = qs.count ?? 0);
    } catch (e) {
      debugPrint('closedReportCount error: $e');
      if (!mounted) return;
      setState(() => closedReportCount = 0);
    }
  }

  Future<void> reload() async {
    setState(() {
      loading = true;
      loadingUsers = true;
      loadingReports = true;
    });

    await Future.wait([
      _loadTodayPostCount(),
      _loadTodayReportCount(),
      _loadOpenReportCount(),
      _loadClosedReportCount(),
      _loadBlockedUserCount(),
    ]);

    if (!mounted) return;
    setState(() {
      loading = false;        // 260107 전경환 추가 총 사용자수 새로고침시 보이게
      loadingUsers = false;   // 260107 전경환 추가 총 사용자수 새로고침시 보이게
      loadingReports = false;
    });
  }

  Future<void> _loadReportCounts() async {
    setState(() => loadingReports = true);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfDay.add(const Duration(days: 1));

      final fs = FirebaseFirestore.instance;

      final todayQ = fs
          .collection('reports')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(startOfTomorrow))
          .count()
          .get();

      final openQ = fs
          .collection('reports')
          .where('status', isEqualTo: 'open')
          .count()
          .get();

      final closedQ = fs
          .collection('reports')
          .where('status', isEqualTo: 'closed')
          .count()
          .get();

      final results = await Future.wait([todayQ, openQ, closedQ]);

      if (!mounted) return;
      setState(() {
        todayReportCount = results[0].count ?? 0;
        openReportCount = results[1].count ?? 0;
        closedReportCount = results[2].count ?? 0;
        loadingReports = false;
        loadingUsers = false;
      });
    } catch (e) {
      debugPrint('loadReportCounts error: $e');
      if (!mounted) return;
      setState(() {
        todayReportCount = 0;
        openReportCount = 0;
        closedReportCount = 0;
        loadingReports = false;
      });
    }
  }

  Future<void> _loadTodayPostCount() async {
    try {
      final now = DateTime.now();
      final start = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

      final postsSnap = await FirebaseFirestore.instance
          .collection('community')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .count()
          .get();
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();

      final weeklyData = await repo.getWeeklyPostCounts();
      final categoryData = await repo.getCategoryCounts();

      if (mounted) {
        setState(() {
          todayPostCount = postsSnap.count ?? 0;
          totalUserCount = usersSnap.count ?? 0;
          weeklyCounts = weeklyData;
          categoryCounts = categoryData;
          totalMediaPosts = categoryData.values.fold(
            0,
            (sum, val) => sum + val,
          );
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('대시보드 데이터 로드 에러: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('요약'),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
              title: '오늘 신고',
              value: loadingReports ? '...' : '$todayReportCount',
              icon: Icons.report,
              onTap: widget.onGoReport,
            ),
            _StatCard(
              title: '미처리',
              value: loadingReports ? '...' : '$openReportCount',
              icon: Icons.timelapse,
              onTap: widget.onGoReport,
            ),
            _StatCard(
              title: '신규 게시글',
              value: loading ? '...' : '$todayPostCount',
              icon: Icons.article,
              onTap: widget.onGoPosts,
            ),
            _StatCard(
              title: '총 사용자',
              value: loadingUsers ? '...' : '$totalUserCount',
              icon: Icons.people,
              onTap: widget.onGoUsers,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('빠른 작업'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add_circle_outline,
                title: '공지 등록',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NoticeCreatePage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.notifications_active_outlined,
                title: '알림 발송(Alarm)',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminAlarmPage()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.campaign_outlined,
                title: '공지 관리',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TitleListPage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.shield_outlined,
                title: '신고 처리',
                onTap: widget.onGoReport,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _sectionTitle('주간 게시글 활동 (최근 7일)'),
        const SizedBox(height: 12),
        loading
            ? const Center(child: CircularProgressIndicator())
            : _buildWeeklyBarChart(),

        Row(
          children: [
            Expanded(
              child: _StatusMetricCard(
                title: '미처리 신고',
                value: loadingReports ? 0 : openReportCount,
                color: Colors.red,
                icon: Icons.report,
                onTap: widget.onGoReport,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusMetricCard(
                title: '처리 완료',
                value: loadingReports ? 0 : closedReportCount,
                color: Colors.green,
                icon: Icons.check_circle,
                onTap: widget.onGoClosedReport,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusMetricCard(
                title: '제재 사용자',
                value: loadingUsers ? 0 : blockedUserCount,
                color: Colors.orange,
                icon: Icons.block,
                onTap: widget.onGoBlockedUsers,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('카테고리별 비중'),
        const SizedBox(height: 12),
        loading
            ? const Center(child: CircularProgressIndicator())
            : _buildCategoryDistribution(),

        // const SizedBox(height: 24),
        // _sectionTitle('최근 시스템 로그'),
        // const SizedBox(height: 10),
        // _buildRecentLogs(),
        // const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWeeklyBarChart() {
    final List<String> days = ['D-6', 'D-5', 'D-4', 'D-3', 'D-2', '어제', '오늘'];
    int maxCount = weeklyCounts.fold(1, (max, e) => e > max ? e : max);

    return Container(
      height: 160, // ✅ 높이를 150에서 160으로 약간 늘려 공간 확보
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ), // ✅ 상하 패딩 조정
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          double ratio = weeklyCounts[i] / maxCount;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${weeklyCounts[i]}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // 막대 높이도 공간에 맞춰 유동적으로 조절
              Container(
                width: 14,
                height: 75 * ratio,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                days[i],
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _categoryRow('사건/이슈', categoryCounts['사건/이슈'] ?? 0, Colors.redAccent),
          const SizedBox(height: 12),
          _categoryRow('수다', categoryCounts['수다'] ?? 0, Colors.blueAccent),
          const SizedBox(height: 12),
          _categoryRow('패션', categoryCounts['패션'] ?? 0, Colors.greenAccent),
          const SizedBox(height: 12),
          _categoryRow(
            '공지사항',
            categoryCounts['공지사항'] ?? 0,
            Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(String label, int count, Color color) {
    double ratio = totalMediaPosts > 0 ? count / totalMediaPosts : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              '$count건 (${(ratio * 100).toInt()}%)',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          backgroundColor: Colors.grey.shade200,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }

  // Widget _buildRecentLogs() {
  //   final logs = [
  //     {'t': '시스템 가동', 's': '대시보드 데이터 연동이 완료되었습니다.', 'time': '방금'},
  //     {'t': '사용자 데이터', 's': '총 $totalUserCount명의 사용자가 등록되어 있습니다.', 'time': '현재'},
  //     {'t': '게시글 데이터', 's': '오늘 총 $todayPostCount건의 제보가 올라왔습니다.', 'time': '오늘'},
  //   ];
  //
  //   return Column(
  //     children: logs.map((l) => Card(
  //       elevation: 0, color: Colors.white,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
  //       child: ListTile(
  //         dense: true,
  //         leading: const CircleAvatar(radius: 12, backgroundColor: Colors.black12, child: Icon(Icons.analytics_outlined, size: 14, color: Colors.black54)),
  //         title: Text(l['t']!, style: const TextStyle(fontWeight: FontWeight.bold)),
  //         subtitle: Text(l['s']!),
  //         trailing: Text(l['time']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  //       ),
  //     )).toList(),
  //   );
  // }
}

/* -------------------- 2) 게시글 관리 -------------------- */
class _AdminPostListPage extends StatefulWidget {
  const _AdminPostListPage();
  @override
  State<_AdminPostListPage> createState() => _AdminPostListPageState();
}

class _AdminPostListPageState extends State<_AdminPostListPage> {
  String _keyword = '';
  String _selectedCategory = '전체';

  final List<String> _categories = ['전체', '사건/이슈', '수다', '패션', '공지사항'];


  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('게시글 관리'),
        const SizedBox(height: 10),

        // ✅ 카테고리 필터 칩 추가
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat, style: TextStyle(
                    // color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
                  selected: isSelected,
                  // selectedColor: const Color(0xFF1A237E), // AppBar와 맞춘 딥 네이비
                  // backgroundColor: Colors.grey.shade200,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),
        _SearchBar(
          hintText: '제목/내용 검색',
          onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('community')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            
            final docs = snapshot.data!.docs.where((d) {
              final data = d.data();
              final category = (data['category'] ?? '미분류').toString();
              
              // ✅ 카테고리 필터링 조건 추가
              final matchesCategory = _selectedCategory == '전체' || category == _selectedCategory;
              
              // ✅ 키워드 필터링 조건
              final matchesKeyword = (data['title'] ?? '').toString().toLowerCase().contains(_keyword) ||
                  (data['plain'] ?? '').toString().toLowerCase().contains(_keyword);
              
              return matchesCategory && matchesKeyword;
            }).toList();
            
            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text('해당하는 게시글이 없습니다.', style: TextStyle(color: Colors.grey)),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final category = (data['category'] ?? '미분류').toString();
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        category == '공지사항' ? Icons.campaign : Icons.article,
                      ),
                    ),
                    title: Text(
                      data['title'] ?? '(제목없음)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$category · ${data['user_nickname'] ?? '익명'} · 이미지 ${(data['images'] as List?)?.length ?? 0}',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminPostDetailPage(docId: doc.id),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

/* -------------------- 3) 신고 관리 -------------------- */
class _AdminReportPage extends StatefulWidget {
  final String initialFilter; // 'open' | 'closed' | 'all'
  const _AdminReportPage({super.key, this.initialFilter = 'open'});

  @override
  State<_AdminReportPage> createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<_AdminReportPage> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter; // ✅ 여기서 초기값 세팅
  }

  Query<Map<String, dynamic>> _query() {
    final col = FirebaseFirestore.instance.collection('reports');

    if (_filter == 'open') return col.where('status', isEqualTo: 'open');
    if (_filter == 'closed') return col.where('status', isEqualTo: 'closed');
    return col.orderBy('createdAt', descending: true);
  }

  String _fmt(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  // jgh260109----S 신고 결과 텍스트 변환 함수
  String _getResolutionText(String? res) {
    switch (res) {
      case 'dismissed':
        return '무혐의';
      case 'deleted_post':
        return '게시글 삭제';
      case 'blocked_user':
        return '사용자 제재';
      case 'both':
        return '삭제+제재';
      case 'hidden_post':
        return '숨김 처리';
      default:
        return '처리됨';
    }
  }
  // jgh260109----E 신고 결과 텍스트 변환 함수

  @override
  Widget build(BuildContext context) {
    final stream = _query().snapshots();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('신고 관리'),
        const SizedBox(height: 10),

        // ✅ 필터 토글
        Row(
          children: [
            ChoiceChip(
              label: const Text('전체'),
              selected: _filter == 'all',
              onSelected: (_) => setState(() => _filter = 'all'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('미처리'),
              selected: _filter == 'open',
              onSelected: (_) => setState(() => _filter = 'open'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('처리완료'),
              selected: _filter == 'closed',
              onSelected: (_) => setState(() => _filter = 'closed'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('에러: ${snap.error}'),
              );
            }

            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs; // ✅ 이 줄이 핵심!
            if (docs.isEmpty) {
              return const Center(child: Text('신고 데이터가 없습니다.'));
            }

            return Column(
              children: docs.map((d) {
                final r = d.data();
                final title = (r['postTitle'] ?? '(제목없음)').toString();
                final reason = (r['reason'] ?? '').toString();
                final category = (r['category'] ?? '').toString();
                final postId = (r['postId'] ?? '').toString();
                final status = (r['status'] ?? 'open').toString();
                final resolution = r['resolution'] as String?;
                final createdAt = r['createdAt']; // 없을 수도 있음

                final isOpen = status == 'open';

                // jgh260109----S 신고 목록 시각적 구분 코드
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isOpen ? Colors.red.withOpacity(0.2) : Colors.black12,
                      width: isOpen ? 1.5 : 0.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isOpen ? Colors.red.shade50 : Colors.grey.shade100,
                        child: Icon(
                          isOpen ? Icons.report_problem : Icons.check_circle_outline,
                          color: isOpen ? Colors.red : Colors.grey,
                        ),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isOpen ? Colors.red : Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOpen ? '미처리' : '처리완료',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    isOpen ? FontWeight.bold : FontWeight.normal,
                                color: isOpen ? Colors.black : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '[$category] 사유: $reason\n${isOpen ? "" : "[결과: ${_getResolutionText(resolution)}] "}${_fmt(createdAt)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isOpen ? Colors.black87 : Colors.black45,
                        ),
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          OutlinedButton(
                            onPressed: postId.isEmpty
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AdminPostDetailPage(docId: postId),
                                      ),
                                    );
                                  },
                            child: const Text('원문'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminReportDetailPage(reportId: d.id),
                                ),
                              );
                            },
                            child: const Text('처리'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                // jgh260109----E 신고 목록 시각적 구분 코드
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

/* -------------------- 4) 사용자들 -------------------- */
class _AdminUsersPage extends StatefulWidget {
  final bool blockedOnly; // 초기값 용도
  const _AdminUsersPage({super.key, this.blockedOnly = false});

  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

// ====== (너가 만든 제재 관련 함수들: 그대로 둬도 됨) ======
Future<void> _logBlockAction({
  required String userId,
  required String action, // 'unblock' | 'extend' | 'reason_update'
  String? reason,
  int? days,
  String? adminId,
}) async {
  await FirebaseFirestore.instance.collection('user_block_logs').add({
    'userId': userId,
    'action': action,
    'reason': reason,
    'days': days,
    'adminId': adminId,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _unblockUser({
  required String userId,
  String? adminId,
}) async {
  final now = Timestamp.fromDate(DateTime.now());

  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'writeBlockedUntil': now,
  });

  await _logBlockAction(
    userId: userId,
    action: 'unblock',
    adminId: adminId,
  );
}

Future<void> _extendBlock({
  required String userId,
  required Timestamp? currentUntil,
  required int days,
  String? adminId,
}) async {
  final nowDt = DateTime.now();
  final baseDt = (currentUntil != null && currentUntil.toDate().isAfter(nowDt))
      ? currentUntil.toDate()
      : nowDt;

  final nextUntil = Timestamp.fromDate(baseDt.add(Duration(days: days)));

  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'writeBlockedUntil': nextUntil,
  });

  await _logBlockAction(
    userId: userId,
    action: 'extend',
    days: days,
    adminId: adminId,
  );
}

Future<String?> _inputReasonDialog(BuildContext context, String initial) async {
  final controller = TextEditingController(text: initial);

  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('제재 사유'),
      content: TextField(
        controller: controller,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: '사유를 입력하세요',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('저장'),
        ),
      ],
    ),
  );
}

Future<void> _updateBlockReason({
  required String userId,
  required String reason,
  String? adminId,
}) async {
  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'writeBlockReason': reason,
  });

  await _logBlockAction(
    userId: userId,
    action: 'reason_update',
    reason: reason,
    adminId: adminId,
  );
}
// ======================================================

class _AdminUsersPageState extends State<_AdminUsersPage> {
  String _keyword = '';
  late bool _blockedOnly;

  @override
  void initState() {
    super.initState();
    _blockedOnly = widget.blockedOnly;
  }

  @override
  void didUpdateWidget(covariant _AdminUsersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blockedOnly != widget.blockedOnly) {
      setState(() => _blockedOnly = widget.blockedOnly);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = Timestamp.fromDate(DateTime.now());

    final Stream<QuerySnapshot<Map<String, dynamic>>> userStream = _blockedOnly
        ? FirebaseFirestore.instance
        .collection('users')
        .where('writeBlockedUntil', isGreaterThan: now)
        .snapshots()
        : FirebaseFirestore.instance.collection('users').snapshots();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('사용자들'),
        const SizedBox(height: 10),

        Row(
          children: [
            ChoiceChip(
              label: const Text('전체'),
              selected: _blockedOnly == false,
              onSelected: (_) => setState(() => _blockedOnly = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('제재 사용자'),
              selected: _blockedOnly == true,
              onSelected: (_) => setState(() => _blockedOnly = true),
            ),
          ],
        ),

        const SizedBox(height: 10),
        _SearchBar(
          hintText: '이름/닉네임 검색',
          onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs.where((d) {
              final data = d.data();
              return (data['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_keyword) ||
                  (data['nickName'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(_keyword);
            }).toList();

            if (docs.isEmpty) {
              return Center(
                child: Text(_blockedOnly ? '제재 사용자가 없습니다.' : '사용자가 없습니다.'),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final profileUrl = (data['profile_image_url'] ?? '').toString();

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        if (profileUrl.startsWith('http')) {
                          _showEnlargedImage(context, profileUrl);
                        }
                      },
                      child: CircleAvatar(
                        backgroundImage: profileUrl.startsWith('http')
                            ? NetworkImage(profileUrl)
                            : null,
                        child: profileUrl.startsWith('http')
                            ? null
                            : const Icon(Icons.person),
                      ),
                    ),
                    title: Text(data['nickName'] ?? data['name'] ?? '알수없음'),
                    subtitle: Text(data['email'] ?? '-'),
                    onTap: () => _showUserDetailDialog(context, doc.id),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showEnlargedImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetailDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(docId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snap.data!.data();
            if (data == null) {
              return const SizedBox(
                height: 120,
                child: Center(child: Text('정보를 불러올 수 없습니다.')),
              );
            }

            String s(String k) => (data[k] ?? '-').toString();
            bool b(String k) => data[k] == true;

            String createdDate = '-';
            final ts = data['createdAt'];
            if (ts is Timestamp) {
              final dt = ts.toDate().toLocal();
              createdDate =
              '${dt.year}.${dt.month}.${dt.day} ${dt.hour}:${dt.minute}';
            }

            String blockedUntilText = '-';
            final wb = data['writeBlockedUntil'];
            Timestamp? blockedUntilTs;
            if (wb is Timestamp) {
              blockedUntilTs = wb;
              final dt = wb.toDate().toLocal();
              blockedUntilText =
              '${dt.year}.${dt.month}.${dt.day} ${dt.hour}:${dt.minute}';
            }

            final blockReason = (data['writeBlockReason'] ?? '').toString();
            final String? adminId = null; // 나중에 FirebaseAuth 붙이면 여기 넣기

            final String profileImageUrl = s('profile_image_url');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (profileImageUrl.startsWith('http')) {
                            _showEnlargedImage(context, profileImageUrl);
                          }
                        },
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: profileImageUrl.startsWith('http')
                              ? NetworkImage(profileImageUrl)
                              : null,
                          child: profileImageUrl.startsWith('http')
                              ? null
                              : const Icon(Icons.person, size: 30),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s('nickName'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              s('email'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  _infoTile('이름', s('name')),
                  _infoTile('연락처', s('phone')),
                  _infoTile('성별', s('gender')),
                  _infoTile('소개', s('intro')),
                  _infoTile('가입일', createdDate),
                  _infoTile('제재 해제', blockedUntilText),

                  // ✅ 제재 탭에서 열었을 때만 제재 관리 버튼 노출
                  if (_blockedOnly) ...[
                    const Divider(height: 30),
                    const Text(
                      '제재 관리',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _infoTile('제재 사유', blockReason.isEmpty ? '-' : blockReason),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('사유 수정'),
                          onPressed: () async {
                            final newReason =
                            await _inputReasonDialog(context, blockReason);
                            if (newReason == null) return;

                            await _updateBlockReason(
                              userId: docId,
                              reason: newReason,
                              adminId: adminId,
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.lock_open, size: 18),
                          label: const Text('제재 해제'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            await _unblockUser(userId: docId, adminId: adminId);
                          },
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await _extendBlock(
                              userId: docId,
                              currentUntil: blockedUntilTs,
                              days: 7,
                              adminId: adminId,
                            );
                          },
                          child: const Text('+7일'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await _extendBlock(
                              userId: docId,
                              currentUntil: blockedUntilTs,
                              days: 30,
                              adminId: adminId,
                            );
                          },
                          child: const Text('+30일'),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 15),
                  const Text('설정 현황',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _statusPill('알림', b('isAlramChecked')),
                      _statusPill('위치', b('isLocationChecked')),
                      _statusPill('카메라', b('isCameraChecked')),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text(
                    '시스템 정보 (고유 키)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _keyRow('Doc ID', docId),
                  _keyRow('Auth UID', s('uid')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기',
                          style: TextStyle(color: Colors.white)),
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

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          SelectableText(
            key,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.blueGrey,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool isOn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOn ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: ${isOn ? "ON" : "OFF"}',
        style: TextStyle(
          fontSize: 11,
          color: isOn ? Colors.green : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


/* -------------------- 공용 위젯 -------------------- */
Widget _sectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
  );
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final VoidCallback? onTap;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 0,
        color: Colors.black.withOpacity(0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.hintText, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _StatusMetricCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatusMetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                foregroundColor: color,
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
