import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/community/CommunityView.dart';

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
    // 상단에서 이미 uid를 선언했다고 가정 (final String? uid = ...)
    if (uid == null) return;

    try {
      // 1. snapshots() 대신 get()을 사용하여 현재 상태의 문서들을 가져옵니다.
      final querySnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();

        for (var doc in querySnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }

        // 2. 일괄 업데이트 실행
        await batch.commit();
        debugPrint("${querySnapshot.docs.length}개의 알림을 읽음 처리했습니다.");
      }
    } catch (e) {
      debugPrint("읽음 처리 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("로그인이 필요합니다."));
    return PutterScaffold(
      currentIndex: 3,
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: Column(
          children: [
            // --- 상단 커스텀 헤더 ---
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 10, // 여백 조정
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))],
              ),
              child: Stack( // 양쪽 배치를 위해 Stack 또는 Row 사용
                alignment: Alignment.center,
                children: [
                  const Text(
                      "알림함",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _markAllAsRead, // ✅ 버튼 클릭 시 일괄 읽음 함수 실행
                      child: const Text(
                          "모두 읽기",
                          style: TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.w600)
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- 알림 리스트 (기존과 동일) ---
            Expanded(
              child: uid == null
                  ? const Center(child: Text("로그인이 필요합니다."))
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('receiverUid', isEqualTo: user.uid)
                    .orderBy('createdAt', descending: true) // 👈 필터링 없이 정렬만 함
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('알림 로드 오류: ${snapshot.error}'));
                  }
                  // ... (기존 snapshot 처리 로직 동일)
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
      onTap: () async {
        // 1. 읽음 처리
        try {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(docId)
              .update({'isRead': true});
        } catch (e) {
          debugPrint("읽음 처리 실패: $e");
        }

        // 2. 중요: 보내주신 데이터 구조에 맞춰 postId 추출
        // toString()을 확실히 하고 trim()으로 공백 제거
        final String pId = (
            data['postId'] ??    // 대문자 I
                data['postid'] ??    // 소문자 i
                data['postID'] ??    // 전체 대문자 ID
                data['id'] ??        // 그냥 id
                ''
        ).toString().trim();

        debugPrint("📍 클릭한 알림의 postId 값: '$pId'");

        // 3. 이동 로직 (조건문 강화)
        if (pId.isNotEmpty && pId != 'null' && pId != 'undefined') {
          debugPrint("🚀 상세 페이지(Communityview)로 이동합니다. ID: $pId");

          // context가 살아있는지 확인 후 이동
          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Communityview(docId: pId),
            ),
          );
        } else {
          // postId가 진짜로 없을 때만 홈으로 이동
          debugPrint("⚠️ postId가 데이터에 없어서 홈으로 이동합니다. data내용: $data");

          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
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