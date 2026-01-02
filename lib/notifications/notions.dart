import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/mypage/DetailMypost.dart'; // 상세 페이지 경로 확인

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .orderBy('createdAt', descending: true) // 최신순 정렬
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("도착한 알림이 없습니다.", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final String title = doc['title'] ?? '알림';
                    final String body = doc['body'] ?? '';
                    final String? postId = doc['postId']; // Cloud Functions에서 저장한 ID

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.notifications, color: Colors.blue),
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                        _formatTimestamp(doc['createdAt']),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () {

                        if (postId != null && postId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Detailmypost(
                                postId: postId,
                                imageUrl: '',
                                postData: const {},
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("연결된 게시글을 찾을 수 없습니다.")),
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