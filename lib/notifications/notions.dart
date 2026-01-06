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
    // 2초 뒤에 모든 알림을 읽음 처리
    Future.delayed(const Duration(seconds: 2), () => _markAllAsRead());
  }

  Future<void> _markAllAsRead() async {
    if (uid == null) return;
    try {
      final snapshots = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: uid)
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
    return PutterScaffold(
      currentIndex: 3,
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: Column(
          children: [
            // --- 상단 커스텀 헤더 ---
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))],
              ),
              child: const Center(
                child: Text("알림함", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),

            // --- 알림 리스트 ---
            Expanded(
              child: uid == null
                  ? const Center(child: Text("로그인이 필요합니다."))
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                // .where('receiverId', isEqualTo: uid) // 데이터 구조에 따라 주석 해제하여 사용
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text("아직 도착한 알림이 없어요", style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildNotificationItem(doc.id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String docId, Map<String, dynamic> data) {
    final bool isRead = data['isRead'] ?? false;
    final String title = data['title'] ?? '알림';
    final String body = data['body'] ?? '';
    final dynamic timestamp = data['createdAt'];

    return GestureDetector(
      onTap: () {
        FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});

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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF1F8FF),
          borderRadius: BorderRadius.circular(16),
          border: isRead ? Border.all(color: Colors.grey[200]!) : Border.all(color: Colors.blue[100]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘 부분
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isRead ? Colors.grey[100] : Colors.blue[50],
                shape: BoxShape.circle, // ✅ BoxType.circle을 BoxShape.circle로 수정
              ),
              child: Icon(
                title.contains('댓글') ? Icons.chat_bubble_rounded : Icons.notifications_rounded,
                color: isRead ? Colors.grey : Colors.blueAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // 텍스트 부분
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 15)),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "방금 전";

    DateTime date;

    // 타입에 따라 안전하게 DateTime으로 변환
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return "방금 전";
    }

    DateTime now = DateTime.now();

    // 오늘인 경우 시간 표시, 아니면 날짜 표시
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "${date.month}/${date.day}";
  }
}

// ✅ PutterScaffold 클래스가 반드시 같은 파일 하단 혹은 import 가능한 곳에 있어야 합니다.
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
        type: BottomNavigationBarType.fixed,
        currentIndex: widget.currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: '알림'),
        ],
      ),
    );
  }
}