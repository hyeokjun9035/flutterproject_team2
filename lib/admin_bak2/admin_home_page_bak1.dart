import 'package:flutter/material.dart';

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
            icon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: '게시글',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: '신고',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardPage extends StatelessWidget {
  const _AdminDashboardPage();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('관리자 대시보드'));
  }
}

class _AdminPostListPage extends StatelessWidget {
  const _AdminPostListPage();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('게시글 관리'));
  }
}

class _AdminReportPage extends StatelessWidget {
  const _AdminReportPage();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('신고 관리'));
  }
}

class _AdminSettingPage extends StatelessWidget {
  const _AdminSettingPage();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('관리자 설정'));
  }
}
