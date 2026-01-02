import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_board_title/title_list_page.dart';
import 'postDetailPage.dart';
import 'notices/notice_create_page.dart';

// void main() {
//   runApp(const MaterialApp(home: AdminHomePage()));
// }

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<_AdminDashboardPageState> _dashboardKey =
      GlobalKey<_AdminDashboardPageState>();

  int _currentIndex = 0;

  // ✅ 여기 추가 260102
  void _goToReportTab() {
    setState(() => _currentIndex = 2);
  }

  late final List<Widget> _pages = [
    _AdminDashboardPage(
      key: _dashboardKey,
      onGoReport: _goToReportTab,
      onGoPosts: () => setState(() => _currentIndex = 1), // ✅ 추가
      onGoUsers: () => setState(() => _currentIndex = 3), // ✅ 추가
    ),
    _AdminPostListPage(),
    const _AdminReportPage(),
    const _AdminUsersPage(),
  ];

  void _logout() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false, // ✅ 스택 전부 제거 (뒤로가기 차단)
    );
  }

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
            tooltip: '알림',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('알림(예정)')));
            },
            icon: const Icon(Icons.notifications_none),
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
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.settings_outlined),
          //   label: '설정',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline), // ✅ 아이콘도 사용자로
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
  final VoidCallback onGoPosts; // ✅ 추가
  final VoidCallback onGoUsers; // ✅ 추가

  const _AdminDashboardPage({
    super.key,
    required this.onGoReport,
    required this.onGoPosts, // ✅ 추가
    required this.onGoUsers, // ✅ 추가
  });

  @override
  State<_AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<_AdminDashboardPage> {
  int todayPostCount = 0;
  bool loading = true;
  int totalUserCount = 0; // ✅ 총 사용자 수
  bool loadingUsers = true; // ✅ 사용자 로딩 표시

  @override
  void initState() {
    super.initState();
    _loadTodayPostCount();
    _loadTotalUserCount(); // ✅ 총 사용자 수 가져오기
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
          .count() // ✅ 서버에서 count만
          .get();

      if (!mounted) return;
      setState(() {
        todayPostCount = qs.count ?? 0; // ✅ 오늘 글 개수
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
        totalUserCount = qs.size; // ✅ users 전체 문서 개수 (사용자수)
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
              onTap: widget.onGoReport, // ✅ 신고 탭으로 이동
            ),
            _StatCard(
              title: '미처리(하드코딩)',
              value: '3',
              icon: Icons.timelapse,
              onTap: widget.onGoReport, // ✅ 신고 탭으로 이동
            ),
            _StatCard(
              title: '신규 게시글',
              value: loading ? '...' : '$todayPostCount',
              icon: Icons.article,
              onTap: widget.onGoPosts, // ✅ 게시글 탭으로 이동
            ),
            _StatCard(
              title: '총 사용자',
              value: loadingUsers ? '...' : '$totalUserCount',
              icon: Icons.people,
              onTap: widget.onGoUsers, // ✅ 사용자들 탭으로 이동
            ),
          ],
        ),

        const SizedBox(height: 18),
        _sectionTitle('빠른 작업'),
        const SizedBox(height: 10),

        // 빠른 작업
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
          ],
        ),
        const SizedBox(height: 12),
        _QuickActionButton(
          icon: Icons.shield_outlined,
          title: '신고 처리',
          onTap: () {
            // 260102 주석처리
            // ScaffoldMessenger.of(context).showSnackBar(
            //const SnackBar(content: Text('신고 처리 화면 연결(예정)')),
            // );
            widget.onGoReport(); // ✅ 신고 탭으로 전환 260102
          },
        ),

        //     260102 도표를 위해 일단 주석처리
        //     const SizedBox(height: 18),
        //     _sectionTitle('최근 처리 로그'),
        //     const SizedBox(height: 10),
        //
        //     Card(
        //       elevation: 0,
        //       color: Colors.black.withOpacity(0.04),
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(14),
        //       ),
        //       child: Column(
        //         children: const [
        //           _LogTile(
        //             title: '신고 #102 처리 완료',
        //             subtitle: '스팸 게시글 삭제',
        //             time: '방금',
        //           ),
        //           Divider(height: 1),
        //           _LogTile(title: '공지 등록', subtitle: '서버 점검 안내', time: '10분 전'),
        //           Divider(height: 1),
        //           _LogTile(title: '신고 #97 보류', subtitle: '추가 확인 필요', time: '1시간 전'),
        //         ],
        //       ),
        //     ),
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

// class _AdminPostListPage extends StatelessWidget {
//   const _AdminPostListPage();
//
//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: const EdgeInsets.all(14),
//       children: [
//         _sectionTitle('게시글 관리'),
//         const SizedBox(height: 10),
//         _SearchBar(
//           hintText: '제목/작성자 검색',
//           onChanged: (v) {},
//         ),
//         const SizedBox(height: 12),
//
//         ...List.generate(8, (i) {
//           return Card(
//             elevation: 0,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//             child: ListTile(
//               leading: const CircleAvatar(child: Icon(Icons.article)),
//               title: Text('게시글 제목 예시 #${i + 1}'),
//               subtitle: const Text('작성자: user01 · 댓글 3 · 좋아요 12'),
//               trailing: PopupMenuButton<String>(
//                 onSelected: (v) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('$v (예정)')),
//                   );
//                 },
//                 itemBuilder: (_) => const [
//                   PopupMenuItem(value: '보기', child: Text('보기')),
//                   PopupMenuItem(value: '숨김', child: Text('숨김')),
//                   PopupMenuItem(value: '삭제', child: Text('삭제')),
//                 ],
//               ),
//             ),
//           );
//         }),
//       ],
//     );
//   }
// }

class _AdminPostListPage extends StatefulWidget {
  const _AdminPostListPage();

  @override
  State<_AdminPostListPage> createState() => _AdminPostListPageState();
}

class _AdminPostListPageState extends State<_AdminPostListPage> {
  String _keyword = '';

  // ✅ 최신 50개 (status=active만 보이게)
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamPosts() {
    return FirebaseFirestore.instance
        .collection('community')
        // .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        //     .orderBy('cdate', descending: true)
        .limit(50)
        .snapshots();
  }

  String _fmtTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal(); // ✅ 로컬시간(KST)로 변환
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  String fmtKstFixed(dynamic ts) {
    if (ts is! Timestamp) return '-';

    // ✅ Timestamp는 본질적으로 UTC 기준
    final dtKst = DateTime.fromMillisecondsSinceEpoch(
      ts.millisecondsSinceEpoch,
      isUtc: true,
    ).add(const Duration(hours: 9)); // KST 고정

    return '${dtKst.year}-${dtKst.month.toString().padLeft(2, '0')}-${dtKst.day.toString().padLeft(2, '0')} '
        '${dtKst.hour.toString().padLeft(2, '0')}:${dtKst.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _hidePost(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('숨김 처리'),
        content: const Text('이 게시글을 숨김 처리할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('숨김'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance.collection('community').doc(docId).update({
      'status': 'hidden',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('숨김 처리 완료')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('게시글 관리'),
        const SizedBox(height: 10),

        _SearchBar(
          hintText: '제목/내용 검색(간단)',
          onChanged: (v) => setState(() => _keyword = v.trim()),
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _streamPosts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            // if (snapshot.hasError) {
            //   return Padding(
            //     padding: const EdgeInsets.only(top: 24),
            //     child: Text('에러: ${snapshot.error}'),
            //   );
            // }
            if (snapshot.hasError) {
              final err = snapshot.error.toString();

              // ✅ 긴 로그도 끊어서 콘솔에 찍기 (URL 잘림 방지)
              const chunkSize = 900;
              for (int i = 0; i < err.length; i += chunkSize) {
                final end = (i + chunkSize < err.length)
                    ? i + chunkSize
                    : err.length;
                debugPrint('FirestoreError: ${err.substring(i, end)}');
              }

              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text('에러가 발생했습니다. 콘솔(Logcat)을 확인하세요.'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            // ✅ Firestore는 부분검색이 어려워서 초기버전은 클라 필터링
            final filtered = _keyword.isEmpty
                ? docs
                : docs.where((d) {
                    final data = d.data();
                    final title = (data['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    // final content = (data['content'] ?? '').toString().toLowerCase();
                    final plain = (data['plain'] ?? data['content'] ?? '')
                        .toString()
                        .toLowerCase();
                    final key = _keyword.toLowerCase();
                    // return title.contains(key) || content.contains(key);
                    return title.contains(key) || plain.contains(key);
                  }).toList();

            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: Text('게시글이 없습니다')),
              );
            }

            return Column(
              children: filtered.map((doc) {
                final data = doc.data();

                final title = (data['title'] ?? '(제목 없음)').toString();

                // category (new) or board_type (old)
                final category =
                    (data['category'] ?? data['board_type'] ?? '미분류')
                        .toString();

                // writer (new: author.nickName) or (old: nickName/user_id)
                String writer = 'unknown';
                final author = data['author'];
                if (author is Map) {
                  writer =
                      (author['nickName'] ??
                              author['name'] ??
                              author['uid'] ??
                              'unknown')
                          .toString();
                } else {
                  writer = (data['nickName'] ?? data['user_id'] ?? 'unknown')
                      .toString();
                }

                // time (new: createdAt) or (old: cdate)
                final createdAt = data['createdAt'] ?? data['cdate'];

                // images (new: images) or (old: image_urls)
                final imagesRaw = data['images'] ?? data['image_urls'];
                final imgCount = (imagesRaw is List) ? imagesRaw.length : 0;

                // report count (old schema only, 없으면 0)
                final reportCount = (data['report_count'] ?? 0);

                // notice icon 판단
                final isNotice = category == '공지사항';

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(isNotice ? Icons.campaign : Icons.article),
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$category · $writer · ${fmtKstFixed(createdAt)} · 이미지 $imgCount · 신고 $reportCount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminPostDetailPage(docId: doc.id),
                        ),
                      );
                    },
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.report, color: Colors.red),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '미처리 신고가 있습니다. 빠르게 확인하세요.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        ...List.generate(6, (i) {
          final status = (i % 3 == 0)
              ? '미처리'
              : (i % 3 == 1)
              ? '처리중'
              : '완료';
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '신고 #${120 + i}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      _StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('사유: 욕설/비방'),
                  const SizedBox(height: 6),
                  const Text(
                    '대상: 게시글 제목 예시',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('상세보기(예정)')),
                            );
                          },
                          child: const Text('상세보기'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('처리하기(예정)')),
                            );
                          },
                          child: const Text(
                            '처리하기',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/* -------------------- 4) 설정 -------------------- */

class _AdminSettingPage extends StatelessWidget {
  final VoidCallback onLogout;

  const _AdminSettingPage({required this.onLogout, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('설정'),
        const SizedBox(height: 10),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: true,
                onChanged: (_) {},
                title: const Text('푸시 알림 받기'),
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('관리자 권한/보안'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('보안 설정(예정)')));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                // onTap: () {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('로그아웃(예정)')),
                // );
                // },
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ],
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
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap; // ✅ 추가

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap, // ✅ 추가
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // ✅ 터치 가능하게
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
                    Text(title, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
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

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case '미처리':
        bg = Colors.red.withOpacity(0.12);
        fg = Colors.red;
        break;
      case '처리중':
        bg = Colors.orange.withOpacity(0.12);
        fg = Colors.orange;
        break;
      default: // 완료
        bg = Colors.green.withOpacity(0.12);
        fg = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;

  const _LogTile({
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: const TextStyle(color: Colors.black54, fontSize: 12),
      ),
    );
  }
}

class _StatusMetricCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  final IconData icon;

  const _StatusMetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$value 건',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final bool checked;
  final String title;
  final String subtitle;

  const _ChecklistItem({
    required this.checked,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = checked ? Colors.green : Colors.red;

    return ListTile(
      leading: Icon(
        checked ? Icons.check_circle : Icons.radio_button_unchecked,
        color: color,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: Text(
        checked ? '완료' : '미완료',
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.04),
      ),
    );
  }
}

class _AdminUsersPage extends StatefulWidget {
  const _AdminUsersPage();

  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<_AdminUsersPage> {
  String _keyword = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('name') // ✅ name 없으면 nickName 등으로 바꿔도 됨
        .limit(100)
        .snapshots();
  }

  //260102-------------------S

  void _showUserDetailDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      barrierDismissible: true,
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
                height: 180,
                child: Center(child: Text('사용자 정보가 없습니다')),
              );
            }

            String s(String k) => (data[k] ?? '').toString();
            bool b(String k) => (data[k] == true);

            final name = s('name');
            final nick = s('nickName');
            final email = s('email');
            final phone = s('phone');
            final gender = s('gender');
            final intro = s('intro');
            final uid = s('uid');
            final profileUrl = s('profile_image_url');

            final createdAt = data['createdAt'];
            String createdText = '-';
            if (createdAt is Timestamp) {
              final dt = createdAt.toDate().toLocal();
              createdText =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: profileUrl.startsWith('http')
                            ? NetworkImage(profileUrl)
                            : null,
                        child: profileUrl.startsWith('http')
                            ? null
                            : const Icon(Icons.person),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          nick.isNotEmpty
                              ? '${name.isEmpty ? '(이름없음)' : name} ($nick)'
                              : (name.isEmpty ? '(이름없음)' : name),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  _infoRow('email', email),
                  _infoRow('phone', phone),
                  _infoRow('gender', gender),
                  _infoRow('intro', intro.isEmpty ? '-' : intro),
                  _infoRow('createdAt', createdText),

                  const SizedBox(height: 10),
                  const Text(
                    '설정',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // _pill('알림', b('isAlarmChecked')),
                      _pill('알림', b('isAlramChecked')),
                      _pill('카메라', b('isCameraChecked')),
                      _pill('위치', b('isLocationChecked')),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _infoRow('docId', docId),
                  _infoRow('uid', uid.isEmpty ? '-' : uid),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, bool on) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on
            ? Colors.green.withOpacity(0.12)
            : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: ${on ? "ON" : "OFF"}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: on ? Colors.green : Colors.black87,
        ),
      ),
    );
  }

  //260102-------------------E

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('사용자들'),
        const SizedBox(height: 10),
        _SearchBar(
          hintText: '이름/닉네임/이메일 검색',
          onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _streamUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('사용자 목록 로딩 에러 (콘솔 확인)'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final filtered = _keyword.isEmpty
                ? docs
                : docs.where((d) {
                    final data = d.data();
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final nick = (data['nickName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final email = (data['email'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_keyword) ||
                        nick.contains(_keyword) ||
                        email.contains(_keyword);
                  }).toList();

            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: Text('사용자가 없습니다')),
              );
            }

            return Column(
              children: filtered.map((doc) {
                final data = doc.data();
                final name = (data['name'] ?? '(이름없음)').toString();
                final nick = (data['nickName'] ?? '').toString();
                final email = (data['email'] ?? '').toString();
                final phone = (data['phone'] ?? '').toString();

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      nick.isNotEmpty ? '$name ($nick)' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [email, phone].where((v) => v.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // onTap: () {
                    //   // TODO: 사용자 상세 화면 연결
                    //   ScaffoldMessenger.of(context).showSnackBar(
                    //     SnackBar(content: Text('user docId: ${doc.id}')),
                    //   );
                    // },
                    onTap: () {
                      _showUserDetailDialog(context, doc.id);
                    },
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
