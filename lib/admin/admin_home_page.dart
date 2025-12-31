import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notices/notice_create_page.dart';
import 'notices/notice_list_page.dart';


// void main() {
//   runApp(const MaterialApp(home: AdminHomePage()));
// }

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<_AdminDashboardPageState> _dashboardKey = GlobalKey<_AdminDashboardPageState>();

  int _currentIndex = 0;

  late final List<Widget> _pages = [
    _AdminDashboardPage(key: _dashboardKey),
    _AdminPostListPage(),
    const _AdminReportPage(),
    // const _AdminSettingPage(),
    _AdminSettingPage(onLogout: _logout),
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
                MaterialPageRoute(builder: (_) => const NoticeListPage()),
              );
            },
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () async {
              if (_currentIndex == 0) {
                await _dashboardKey.currentState?.reload();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('새로고침 완료')),
                );
              }
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '알림',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림(예정)')),
              );
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
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

/* -------------------- 1) 대시보드 -------------------- */
class _AdminDashboardPage extends StatefulWidget {
  // const _AdminDashboardPage();
  const _AdminDashboardPage({super.key}); // ✅ key 받도록 변경

  @override
  State<_AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<_AdminDashboardPage> {
  int todayPostCount = 0;
  bool loading = true;
  int totalUserCount = 0;      // ✅ 총 사용자 수
  bool loadingUsers = true;    // ✅ 사용자 로딩 표시

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

    await Future.wait([
      _loadTodayPostCount(),
      _loadTotalUserCount(),
    ]);
  }



  Future<void> _loadTodayPostCount() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfDay.add(const Duration(days: 1));

      final qs = await FirebaseFirestore.instance
          .collection('community')
      // .where('board_type', isEqualTo: '자유게시판')
          .where('cdate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('cdate', isLessThan: Timestamp.fromDate(startOfTomorrow))
          .get();

      if (!mounted) return;
      setState(() {
        todayPostCount = qs.size; // ✅ 오늘 글 개수
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
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .get();

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
            const _StatCard(title: '오늘 신고(하드코딩)', value: '8', icon: Icons.report),
            const _StatCard(title: '미처리(하드코딩)', value: '3', icon: Icons.timelapse),

            // ✅ 여기만 Firestore 값으로 변경
            _StatCard(
              title: '신규 게시글',
              value: loading ? '...' : '$todayPostCount',
              icon: Icons.article,
            ),

            // const _StatCard(title: '활성 사용자', value: '156', icon: Icons.people),
            _StatCard(
              title: '총 사용자',
              value: loadingUsers ? '...' : '$totalUserCount',
              icon: Icons.people,
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
                    MaterialPageRoute(builder: (_) => const NoticeListPage()),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('신고 처리 화면 연결(예정)')),
            );
          },
        ),


        const SizedBox(height: 18),
        _sectionTitle('최근 처리 로그'),
        const SizedBox(height: 10),

        Card(
          elevation: 0,
          color: Colors.black.withOpacity(0.04),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: const [
              _LogTile(
                title: '신고 #102 처리 완료',
                subtitle: '스팸 게시글 삭제',
                time: '방금',
              ),
              Divider(height: 1),
              _LogTile(
                title: '공지 등록',
                subtitle: '서버 점검 안내',
                time: '10분 전',
              ),
              Divider(height: 1),
              _LogTile(
                title: '신고 #97 보류',
                subtitle: '추가 확인 필요',
                time: '1시간 전',
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
        .orderBy('cdate', descending: true)
        .limit(50)
        .snapshots();
  }

  String _fmtTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  Future<void> _hidePost(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('숨김 처리'),
        content: const Text('이 게시글을 숨김 처리할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('숨김')),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance.collection('community').doc(docId).update({
      'status': 'hidden',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('숨김 처리 완료')),
    );
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
                final end = (i + chunkSize < err.length) ? i + chunkSize : err.length;
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
              final title = (data['title'] ?? '').toString().toLowerCase();
              final content = (data['content'] ?? '').toString().toLowerCase();
              final key = _keyword.toLowerCase();
              return title.contains(key) || content.contains(key);
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

                final boardType = (data['board_type'] ?? '미분류').toString();
                final isNotice = (data['is_notice'] == true);
                final title = (data['title'] ?? '(제목 없음)').toString();
                final userId = (data['user_id'] ?? 'unknown').toString();
                final cdate = data['cdate'];
                final reportCount = (data['report_count'] ?? 0);
                final imageUrls = data['image_urls'];
                final imgCount = (imageUrls is List) ? imageUrls.length : 0;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        isNotice || boardType == '공지사항'
                            ? Icons.campaign
                            : Icons.article,
                      ),
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$boardType · $userId · ${_fmtTime(cdate)} · 이미지 $imgCount · 신고 $reportCount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == '숨김') {
                          await _hidePost(doc.id);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$v (예정)')),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: '보기', child: Text('보기')),
                        PopupMenuItem(value: '숨김', child: Text('숨김')),
                      ],
                    ),
                    onTap: () {
                      // TODO: 상세보기 화면 연결(원하면 만들어줄게)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('문서ID: ${doc.id}')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          final status = (i % 3 == 0) ? '미처리' : (i % 3 == 1) ? '처리중' : '완료';
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('신고 #${120 + i}',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      _StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('사유: 욕설/비방'),
                  const SizedBox(height: 6),
                  const Text('대상: 게시글 제목 예시', style: TextStyle(color: Colors.black54)),
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('처리하기(예정)')),
                            );
                          },
                          child: const Text('처리하기', style: TextStyle(color: Colors.white)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('보안 설정(예정)')),
                  );
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

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
      trailing: Text(time, style: const TextStyle(color: Colors.black54, fontSize: 12)),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.hintText,
    required this.onChanged,
  });


  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: Colors.black.withOpacity(0.04),
      ),
    );
  }
}

