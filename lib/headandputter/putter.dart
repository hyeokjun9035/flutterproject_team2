import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PutterScaffold extends StatefulWidget {
  final Widget body;
  final int currentIndex;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget? drawer;

  const PutterScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    this.scaffoldKey, // 추가
    this.drawer,      //추가
  });

  @override
  State<PutterScaffold> createState() => _PutterScaffoldState();
}

class _PutterScaffoldState extends State<PutterScaffold> {
  void _onTap(int index) {
    // if (index == widget.currentIndex) return;
    // ✅ 홈(0)은 현재 탭이어도 항상 홈으로 이동
    if (index == widget.currentIndex && index != 0) return;

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
      case 7:
        Navigator.pushReplacementNamed(context, '/home');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      body: widget.body,
      key: widget.scaffoldKey,
      drawer: widget.drawer,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onTap,
        items:  [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: '홈',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.comment),
            label: '커뮤니티',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이페이지',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<QuerySnapshot>(
              stream: (uid == null)
                ? const Stream.empty()
                : FirebaseFirestore.instance
                  .collection('notifications')
                  .where('receiverUid', isEqualTo: uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Icon(Icons.notifications_active);
                }
                // 읽지 않은 알림 개수
                int unreadCount = snapshot.data!.docs.length;

                //  배지(Badge) 위젯 추가
                return Badge(
                  label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
                  isLabelVisible: unreadCount > 0, // 0개일 때는 숫자를 숨김
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.notifications_active),
                );
              },
            ),
            label: '알림',
          ),
        ],
      ),
    );
  }
}
