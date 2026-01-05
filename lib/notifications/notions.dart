import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/mypage/DetailMypost.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // _cleanupOldNotifications();
    Future.delayed(Duration(seconds: 2), () => _markAllAsRead());
  }

  //  24시간 지난 알림 삭제 로직
  Future<void> _cleanupOldNotifications() async {
    try {
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

      // 최상위 notifications 컬렉션에서 직접 삭제
      final snapshots = await FirebaseFirestore.instance
          .collection('notifications')
          .where('createdAt', isLessThan: twentyFourHoursAgo)
          .get();

      if (snapshots.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print("🗑️ 전역 알림 ${snapshots.docs.length}개 삭제 완료");
      }
    } catch (e) {
      print("❌ 삭제 중 오류 발생: $e");
    }
  }

  Future<void> _markAllAsRead() async {
    if (uid == null) return;
    try {
      final snapshots = await FirebaseFirestore.instance


          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshots.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshots.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      print("읽음 처리 오류: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    print("현재 로그인한 UID: $uid");
    return PutterScaffold(
      currentIndex: 3, // 하단바의 4번째(알림) 아이콘 활성화
      body: Column(
        children: [
          // --- 상단 앱바 ---
          AppBar(
            title: const Text("알림함", style: TextStyle(fontWeight: FontWeight.bold)),
            automaticallyImplyLeading: false,
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),

          // --- 알림 리스트 (실시간) ---
          Expanded(
            child: uid == null
                ? const Center(child: Text("로그인이 필요합니다."))
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 데이터가 없는 경우 처리
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("도착한 알림이 없습니다."));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;


                    final timestamp = data['createdAt'];

                    return ListTile(
                      title: Text(data['title'] ?? '알림'),
                      subtitle: Text(data['body'] ?? ''),
                      trailing: Text(
                        timestamp != null ? _formatTimestamp(timestamp) : "방금 전", // null이면 "방금 전" 표시
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () {
                        String? pId = data['postId'];
                        if (pId != null && pId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Detailmypost(postId: pId, imageUrl: '', postData: const {}),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 시간 표시 포맷 함수
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "";
    DateTime date = (timestamp as Timestamp).toDate();
    return "${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}

// ✅ 하단바가 포함된 공통 스캐폴드 위젯
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
    // 현재 페이지와 같으면 이동 안 함 (단, 홈은 예외)
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.body,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 4개 이상의 아이템일 때 필수 설정
        currentIndex: widget.currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.comment), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이페이지'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active), label: '알림'),
        ],
      ),
    );
  }
}