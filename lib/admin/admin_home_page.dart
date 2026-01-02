import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_board_title/title_list_page.dart';
import 'postDetailPage.dart';
import 'notices/notice_create_page.dart';
import 'admin_alarm_page.dart'; // ✅ 파일명 변경 반영 (alarm 포함)

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<_AdminDashboardPageState> _dashboardKey =
      GlobalKey<_AdminDashboardPageState>();

  int _currentIndex = 0;

  void _goToReportTab() {
    setState(() => _currentIndex = 2);
  }

  late final List<Widget> _pages = [
    _AdminDashboardPage(
      key: _dashboardKey,
      onGoReport: _goToReportTab,
      onGoPosts: () => setState(() => _currentIndex = 1),
      onGoUsers: () => setState(() => _currentIndex = 3),
    ),
    _AdminPostListPage(),
    const _AdminReportPage(),
    const _AdminUsersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 페이지'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '공지 관리',
            icon: const Icon(Icons.campaign),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TitleListPage()),
              );
            },
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () async {
              if (_currentIndex == 0) {
                await _dashboardKey.currentState?.reload();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('새로고침 완료')));
              }
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '알림 발송(Alarm)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAlarmPage()),
              );
            },
            icon: const Icon(Icons.notifications_active),
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

              if (ok != true) return;
              if (!mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),

      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
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
  final VoidCallback onGoPosts;
  final VoidCallback onGoUsers;

  const _AdminDashboardPage({
    super.key,
    required this.onGoReport,
    required this.onGoPosts,
    required this.onGoUsers,
  });

  @override
  State<_AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<_AdminDashboardPage> {
  int todayPostCount = 0;
  bool loading = true;
  int totalUserCount = 0;
  bool loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadTodayPostCount();
    _loadTotalUserCount();
  }

  Future<void> reload() async {
    setState(() {
      loading = true;
      loadingUsers = true;
    });
    await Future.wait([_loadTodayPostCount(), _loadTotalUserCount()]);
  }

  Future<void> _loadTodayPostCount() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfDay.add(const Duration(days: 1));

      final qs = await FirebaseFirestore.instance
          .collection('community')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(startOfTomorrow))
          .count()
          .get();

      if (!mounted) return;
      setState(() {
        todayPostCount = qs.count ?? 0;
        loading = false;
      });
    } catch (e) {
      debugPrint('todayPostCount error: $e');
      if (!mounted) return;
      setState(() {
        todayPostCount = 0;
        loading = false;
      });
    }
  }

  Future<void> _loadTotalUserCount() async {
    try {
      final qs = await FirebaseFirestore.instance.collection('users').get();

      if (!mounted) return;
      setState(() {
        totalUserCount = qs.size;
        loadingUsers = false;
      });
    } catch (e) {
      debugPrint('totalUserCount error: $e');
      if (!mounted) return;
      setState(() {
        totalUserCount = 0;
        loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('요약'),
        const SizedBox(height: 10),

        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          children: [
            _StatCard(
              title: '오늘 신고(하드코딩)',
              value: '8',
              icon: Icons.report,
              onTap: widget.onGoReport,
            ),
            _StatCard(
              title: '미처리(하드코딩)',
              value: '3',
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
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NoticeCreatePage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.notifications_active_outlined,
                title: '알림 발송(Alarm)', // ✅ 명칭 변경
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminAlarmPage()),
                  );
                },
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
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TitleListPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.shield_outlined,
                title: '신고 처리',
                onTap: () => widget.onGoReport(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        _sectionTitle('운영 현황'),
        const SizedBox(height: 10),

        Row(
          children: const [
            Expanded(
              child: _StatusMetricCard(
                title: '미처리 신고',
                value: 3,
                color: Colors.red,
                icon: Icons.report,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatusMetricCard(
                title: '처리 완료',
                value: 12,
                color: Colors.green,
                icon: Icons.check_circle,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatusMetricCard(
                title: '제재 사용자',
                value: 1,
                color: Colors.orange,
                icon: Icons.block,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        _sectionTitle('운영 체크리스트'),
        const SizedBox(height: 10),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            children: [
              _ChecklistItem(
                checked: true,
                title: '미처리 신고 확인',
                subtitle: '신고 게시글 검토 및 조치',
              ),
              Divider(height: 1),
              _ChecklistItem(
                checked: true,
                title: '스팸 게시글 정리',
                subtitle: '광고/도배 게시글 숨김 또는 삭제',
              ),
              Divider(height: 1),
              _ChecklistItem(
                checked: false,
                title: '제재 사용자 확인',
                subtitle: '작성 제한 기간 만료 여부',
              ),
              Divider(height: 1),
              _ChecklistItem(
                checked: false,
                title: '공지사항 점검',
                subtitle: '노출 상태 및 최신화',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* -------------------- 2) 게시글 관리 -------------------- */
class _AdminPostListPage extends StatefulWidget {
  const _AdminPostListPage();
  @override
  State<_AdminPostListPage> createState() => _AdminPostListPageState();
}

class _AdminPostListPageState extends State<_AdminPostListPage> {
  String _keyword = '';
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamPosts() {
    return FirebaseFirestore.instance
        .collection('community')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  String fmtKstFixed(dynamic ts) {
    if (ts is! Timestamp) return '-';
    final dtKst = DateTime.fromMillisecondsSinceEpoch(
      ts.millisecondsSinceEpoch,
      isUtc: true,
    ).add(const Duration(hours: 9));
    return '${dtKst.year}-${dtKst.month.toString().padLeft(2, '0')}-${dtKst.day.toString().padLeft(2, '0')} '
        '${dtKst.hour.toString().padLeft(2, '0')}:${dtKst.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('게시글 관리'),
        const SizedBox(height: 10),
        _SearchBar(hintText: '제목/내용 검색', onChanged: (v) => setState(() => _keyword = v.trim())),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _streamPosts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs.where((d) {
              final data = d.data();
              final title = (data['title'] ?? '').toString().toLowerCase();
              final plain = (data['plain'] ?? data['content'] ?? '').toString().toLowerCase();
              return title.contains(_keyword.toLowerCase()) || plain.contains(_keyword.toLowerCase());
            }).toList();
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final category = (data['category'] ?? data['board_type'] ?? '미분류').toString();
                final isNotice = category == '공지사항';
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(isNotice ? Icons.campaign : Icons.article)),
                    title: Text(data['title'] ?? '(제목없음)', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPostDetailPage(docId: doc.id))),
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
class _AdminReportPage extends StatelessWidget {
  const _AdminReportPage();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('신고 관리'),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: Colors.red.withOpacity(0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [Icon(Icons.report, color: Colors.red), SizedBox(width: 10), Expanded(child: Text('미처리 신고가 있습니다. 빠르게 확인하세요.', style: TextStyle(fontWeight: FontWeight.bold)))],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(3, (i) => Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(title: Text('신고 #${120 + i}'), subtitle: const Text('사유: 부적절한 게시글')),
        )),
      ],
    );
  }
}

/* -------------------- 4) 사용자들 -------------------- */
class _AdminUsersPage extends StatefulWidget {
  const _AdminUsersPage();
  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<_AdminUsersPage> {
  String _keyword = '';
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('사용자들'),
        const SizedBox(height: 10),
        _SearchBar(hintText: '검색', onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase())),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            return Column(children: docs.map((doc) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(doc.data()['nickName'] ?? doc.data()['name'] ?? '알수없음')))).toList());
          },
        ),
      ],
    );
  }
}

/* -------------------- 공용 위젯 -------------------- */
Widget _sectionTitle(String text) {
  return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900));
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const _StatCard({required this.title, required this.value, required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Card(elevation: 0, color: Colors.black.withOpacity(0.04), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [CircleAvatar(backgroundColor: Colors.black, foregroundColor: Colors.white, child: Icon(icon, size: 18)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]))]))));
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)), child: Text(status, style: const TextStyle(fontSize: 12)));
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])));
  }
}

class _StatusMetricCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  final IconData icon;
  const _StatusMetricCard({required this.title, required this.value, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Card(elevation: 0, color: color.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Icon(icon, color: color, size: 20), const SizedBox(height: 4), Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)), Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))])));
  }
}

class _ChecklistItem extends StatelessWidget {
  final bool checked;
  final String title;
  final String subtitle;
  const _ChecklistItem({required this.checked, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked, color: checked ? Colors.green : Colors.grey), title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
  }
}

class _SearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.hintText, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return TextField(onChanged: onChanged, decoration: InputDecoration(hintText: hintText, prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
  }
}
