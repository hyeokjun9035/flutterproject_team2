import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: AdminHomePage()));
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _AdminDashboardPage(),
    _AdminPostListPage(),
    _AdminReportPage(),
    _AdminSettingPage(),
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
            tooltip: '새로고침',
            onPressed: () {
              // TODO: 나중에 데이터 다시 불러오기
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('새로고침(예정)')),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '알림',
            onPressed: () {
              // TODO: 관리자 알림 페이지 연결
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림(예정)')),
              );
            },
            icon: const Icon(Icons.notifications_none),
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

class _AdminDashboardPage extends StatelessWidget {
  const _AdminDashboardPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('요약'),
        const SizedBox(height: 10),

        // 요약 카드 4개
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          children: const [
            _StatCard(title: '오늘 신고', value: '8', icon: Icons.report),
            _StatCard(title: '미처리', value: '3', icon: Icons.timelapse),
            _StatCard(title: '신규 게시글', value: '21', icon: Icons.article),
            _StatCard(title: '활성 사용자', value: '156', icon: Icons.people),
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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('공지 등록 화면 연결(예정)')),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.shield_outlined,
                title: '신고 처리',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('신고 처리 화면 연결(예정)')),
                  );
                },
              ),
            ),
          ],
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

class _AdminPostListPage extends StatelessWidget {
  const _AdminPostListPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('게시글 관리'),
        const SizedBox(height: 10),
        _SearchBar(
          hintText: '제목/작성자 검색',
          onChanged: (v) {},
        ),
        const SizedBox(height: 12),

        ...List.generate(8, (i) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.article)),
              title: Text('게시글 제목 예시 #${i + 1}'),
              subtitle: const Text('작성자: user01 · 댓글 3 · 좋아요 12'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$v (예정)')),
                  );
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: '보기', child: Text('보기')),
                  PopupMenuItem(value: '숨김', child: Text('숨김')),
                  PopupMenuItem(value: '삭제', child: Text('삭제')),
                ],
              ),
            ),
          );
        }),
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
  const _AdminSettingPage();

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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그아웃(예정)')),
                  );
                },
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

