import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_board_title/title_list_page.dart';
import 'postDetailPage.dart';
import 'notices/notice_create_page.dart';
import 'admin_alarm_page.dart';
import 'data/notice_repository.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<_AdminDashboardPageState> _dashboardKey = GlobalKey<_AdminDashboardPageState>();
  int _currentIndex = 0;

  void _goToReportTab() { setState(() => _currentIndex = 2); }

  late final List<Widget> _pages = [
    _AdminDashboardPage(
      key: _dashboardKey,
      onGoReport: _goToReportTab,
      onGoPosts: () => setState(() => _currentIndex = 1),
      onGoUsers: () => setState(() => _currentIndex = 3),
    ),
    const _AdminPostListPage(),
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
          IconButton(tooltip: '공지 관리', icon: const Icon(Icons.campaign), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TitleListPage()))),
          IconButton(tooltip: '새로고침', icon: const Icon(Icons.refresh), onPressed: () { if (_currentIndex == 0) _dashboardKey.currentState?.reload(); }),
          IconButton(tooltip: '알림 발송(Alarm)', icon: const Icon(Icons.notifications_active), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAlarmPage()))),
          IconButton(tooltip: '로그아웃', icon: const Icon(Icons.logout), onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('로그아웃'), content: const Text('로그아웃 하시겠습니까?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인'))]));
            if (ok == true) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          }),
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
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
          BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: '게시글'),
          BottomNavigationBarItem(icon: Icon(Icons.report_gmailerrorred_outlined), label: '신고'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '사용자들'),
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
  const _AdminDashboardPage({super.key, required this.onGoReport, required this.onGoPosts, required this.onGoUsers});
  @override
  State<_AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<_AdminDashboardPage> {
  final repo = NoticeRepository();
  
  int todayPostCount = 0;
  int totalUserCount = 0;
  bool loading = true;

  List<int> weeklyCounts = [0, 0, 0, 0, 0, 0, 0];
  Map<String, int> categoryCounts = {};
  int totalMediaPosts = 0;

  @override
  void initState() { super.initState(); reload(); }

  Future<void> reload() async {
    setState(() => loading = true);
    try {
      final now = DateTime.now();
      final start = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      
      final postsSnap = await FirebaseFirestore.instance.collection('community').where('createdAt', isGreaterThanOrEqualTo: start).count().get();
      final usersSnap = await FirebaseFirestore.instance.collection('users').count().get();
      
      final weeklyData = await repo.getWeeklyPostCounts();
      final categoryData = await repo.getCategoryCounts();

      if (mounted) {
        setState(() {
          todayPostCount = postsSnap.count ?? 0;
          totalUserCount = usersSnap.count ?? 0;
          weeklyCounts = weeklyData;
          categoryCounts = categoryData;
          totalMediaPosts = categoryData.values.fold(0, (sum, val) => sum + val);
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
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
          children: [
            _StatCard(title: '오늘 신고(하드)', value: '8', icon: Icons.report, onTap: widget.onGoReport),
            _StatCard(title: '미처리(하드)', value: '3', icon: Icons.timelapse, onTap: widget.onGoReport),
            _StatCard(title: '신규 게시글', value: loading ? '...' : '$todayPostCount', icon: Icons.article, onTap: widget.onGoPosts),
            _StatCard(title: '총 사용자', value: loading ? '...' : '$totalUserCount', icon: Icons.people, onTap: widget.onGoUsers),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('빠른 작업'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _QuickActionButton(icon: Icons.add_circle_outline, title: '공지 등록', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeCreatePage())))),
          const SizedBox(width: 12),
          Expanded(child: _QuickActionButton(icon: Icons.notifications_active_outlined, title: '알림 발송(Alarm)', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAlarmPage())))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _QuickActionButton(icon: Icons.campaign_outlined, title: '공지 관리', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TitleListPage())))),
          const SizedBox(width: 12),
          Expanded(child: _QuickActionButton(icon: Icons.shield_outlined, title: '신고 처리', onTap: widget.onGoReport)),
        ]),

        const SizedBox(height: 24),
        _sectionTitle('주간 게시글 활동 (최근 7일)'),
        const SizedBox(height: 12),
        loading ? const Center(child: CircularProgressIndicator()) : _buildWeeklyBarChart(),

        const SizedBox(height: 24),
        _sectionTitle('카테고리별 비중'),
        const SizedBox(height: 12),
        loading ? const Center(child: CircularProgressIndicator()) : _buildCategoryDistribution(),

        const SizedBox(height: 24),
        _sectionTitle('최근 시스템 로그'),
        const SizedBox(height: 10),
        _buildRecentLogs(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWeeklyBarChart() {
    final List<String> days = ['D-6', 'D-5', 'D-4', 'D-3', 'D-2', '어제', '오늘'];
    int maxCount = weeklyCounts.fold(1, (max, e) => e > max ? e : max);

    return Container(
      height: 160, // ✅ 높이를 150에서 160으로 약간 늘려 공간 확보
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), // ✅ 상하 패딩 조정
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          double ratio = weeklyCounts[i] / maxCount;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${weeklyCounts[i]}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              // 막대 높이도 공간에 맞춰 유동적으로 조절
              Container(width: 14, height: 75 * ratio, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Text(days[i], style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _categoryRow('사건/이슈', categoryCounts['사건/이슈'] ?? 0, Colors.redAccent),
          const SizedBox(height: 12),
          _categoryRow('수다', categoryCounts['수다'] ?? 0, Colors.blueAccent),
          const SizedBox(height: 12),
          _categoryRow('패션', categoryCounts['패션'] ?? 0, Colors.greenAccent),
          const SizedBox(height: 12),
          _categoryRow('공지사항', categoryCounts['공지사항'] ?? 0, Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _categoryRow(String label, int count, Color color) {
    double ratio = totalMediaPosts > 0 ? count / totalMediaPosts : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), Text('$count건 (${(ratio * 100).toInt()}%)', style: const TextStyle(fontSize: 11))]),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: ratio, backgroundColor: Colors.grey.shade200, color: color, minHeight: 6, borderRadius: BorderRadius.circular(10)),
      ],
    );
  }

  Widget _buildRecentLogs() {
    final logs = [
      {'t': '시스템 가동', 's': '대시보드 데이터 연동이 완료되었습니다.', 'time': '방금'},
      {'t': '사용자 데이터', 's': '총 $totalUserCount명의 사용자가 등록되어 있습니다.', 'time': '현재'},
      {'t': '게시글 데이터', 's': '오늘 총 $todayPostCount건의 제보가 올라왔습니다.', 'time': '오늘'},
    ];

    return Column(
      children: logs.map((l) => Card(
        elevation: 0, color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
        child: ListTile(
          dense: true,
          leading: const CircleAvatar(radius: 12, backgroundColor: Colors.black12, child: Icon(Icons.analytics_outlined, size: 14, color: Colors.black54)),
          title: Text(l['t']!, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(l['s']!),
          trailing: Text(l['time']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
      )).toList(),
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
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('게시글 관리'),
        const SizedBox(height: 10),
        _SearchBar(hintText: '제목/내용 검색', onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase())),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('community').orderBy('createdAt', descending: true).limit(50).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs.where((d) {
              final data = d.data();
              return (data['title'] ?? '').toString().toLowerCase().contains(_keyword) || (data['plain'] ?? '').toString().toLowerCase().contains(_keyword);
            }).toList();
            return Column(children: docs.map((doc) {
              final data = doc.data();
              final category = (data['category'] ?? '미분류').toString();
              return Card(
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(category == '공지사항' ? Icons.campaign : Icons.article)),
                  title: Text(data['title'] ?? '(제목없음)', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$category · ${data['user_nickname'] ?? '익명'} · 이미지 ${(data['images'] as List?)?.length ?? 0}'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPostDetailPage(docId: doc.id))),
                ),
              );
            }).toList());
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
        const Card(elevation: 0, color: Color(0xFFFFF1F0), child: ListTile(leading: Icon(Icons.report, color: Colors.red), title: Text('미처리 신고가 있습니다.', style: TextStyle(fontWeight: FontWeight.bold)))),
        ...List.generate(3, (i) => Card(elevation: 0, child: ListTile(title: Text('신고 #${120 + i}'), subtitle: const Text('사유: 부적절한 언어 사용')))),
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

  void _showUserDetailDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(docId).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
            final data = snap.data?.data();
            if (data == null) return const SizedBox(height: 100, child: Center(child: Text('정보를 불러올 수 없습니다.')));

            String s(String k) => (data[k] ?? '-').toString();
            bool b(String k) => data[k] == true;

            String createdDate = '-';
            final ts = data['createdAt'];
            if (ts is Timestamp) {
              final dt = ts.toDate().toLocal();
              createdDate = '${dt.year}.${dt.month}.${dt.day} ${dt.hour}:${dt.minute}';
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(radius: 25, backgroundImage: s('profile_image_url').startsWith('http') ? NetworkImage(s('profile_image_url')) : null, child: s('profile_image_url').startsWith('http') ? null : const Icon(Icons.person, size: 30)),
                    const SizedBox(width: 15),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s('nickName'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(s('email'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    )),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ]),
                  const Divider(height: 30),
                  _infoTile('이름', s('name')),
                  _infoTile('연락처', s('phone')),
                  _infoTile('성별', s('gender')),
                  _infoTile('소개', s('intro')),
                  _infoTile('가입일', createdDate),
                  const SizedBox(height: 15),
                  const Text('설정 현황', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    _statusPill('알림', b('isAlramChecked')),
                    _statusPill('위치', b('isLocationChecked')),
                    _statusPill('카메라', b('isCameraChecked')),
                  ]),
                  const Divider(height: 30),
                  const Text('시스템 정보 (고유 키)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  _keyRow('Doc ID', docId),
                  _keyRow('Auth UID', s('uid')),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black), onPressed: () => Navigator.pop(context), child: const Text('닫기', style: TextStyle(color: Colors.white)))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)))]));
  }

  Widget _keyRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          SelectableText(key, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool isOn) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isOn ? Colors.green.withOpacity(0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), child: Text('$label: ${isOn ? "ON" : "OFF"}', style: TextStyle(fontSize: 11, color: isOn ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('사용자들'),
        const SizedBox(height: 10),
        _SearchBar(hintText: '이름/닉네임 검색', onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase())),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs.where((d) {
              final data = d.data();
              return (data['name'] ?? '').toString().toLowerCase().contains(_keyword) || (data['nickName'] ?? '').toString().toLowerCase().contains(_keyword);
            }).toList();
            return Column(children: docs.map((doc) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(doc.data()['nickName'] ?? doc.data()['name'] ?? '알수없음'), subtitle: Text(doc.data()['email'] ?? '-'), onTap: () => _showUserDetailDialog(context, doc.id)))).toList());
          },
        ),
      ],
    );
  }
}

/* -------------------- 공용 위젯 -------------------- */
Widget _sectionTitle(String text) { return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)); }

class _StatCard extends StatelessWidget {
  final String title, value; final IconData icon; final VoidCallback? onTap;
  const _StatCard({required this.title, required this.value, required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Card(elevation: 0, color: Colors.black.withOpacity(0.04), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [CircleAvatar(backgroundColor: Colors.black, foregroundColor: Colors.white, child: Icon(icon, size: 18)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]))])))); }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))); }
}

class _SearchBar extends StatelessWidget {
  final String hintText; final ValueChanged<String> onChanged;
  const _SearchBar({required this.hintText, required this.onChanged});
  @override
  Widget build(BuildContext context) { return TextField(onChanged: onChanged, decoration: InputDecoration(hintText: hintText, prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))); }
}
