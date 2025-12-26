import 'package:flutter/material.dart';

class PutterScaffold extends StatefulWidget {
  final Widget body;
  final int currentIndex;

  const PutterScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
  });

  @override
  State<PutterScaffold> createState() => _PutterScaffoldState();
}

class _PutterScaffoldState extends State<PutterScaffold> {
  void _onTap(int index) {
    if (index == widget.currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/community');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/mypage');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/notice');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.body,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.comment),
            label: '커뮤니티',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이페이지',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
            label: '알림',
          ),
        ],
      ),
    );
  }
}
