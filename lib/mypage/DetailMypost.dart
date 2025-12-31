import 'package:flutter/material.dart';
import 'package:flutter_project/mypage/postDelete.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Detailmypost extends StatefulWidget {
  final String imageUrl;
  final Map<String, dynamic> postData;
  final String postId;

  const Detailmypost({
    super.key,
    required this.imageUrl,
    required this.postData,
    required this.postId,
  });

  @override
  State<Detailmypost> createState() => _DetailmypostState();
}

class _DetailmypostState extends State<Detailmypost> {

  final TextEditingController _commentController = TextEditingController();


  Future<void> _addComment() async {
    final String commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("로그인이 필요합니다.")));
      return;
    }

    try {
      // community -> postId 문서 -> comments 서브 컬렉션에 추가
      await FirebaseFirestore.instance
          .collection('community')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'user_id': user.uid,
        'content': commentText,
        'cdate': FieldValue.serverTimestamp(),
      });

      _commentController.clear(); // 입력 완료 후 필드 비우기
      FocusScope.of(context).unfocus(); // 키보드 닫기
    } catch (e) {
      print("댓글 저장 에러: $e");
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = "";
    if (widget.postData['cdate'] != null) {
      DateTime dt = (widget.postData['cdate'] as Timestamp).toDate();
      dateStr = DateFormat('yyyy.MM.dd HH:mm').format(dt);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("게시글 확인",
            style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 프로필 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(widget.postData['user_id']).get(),
                builder: (context, snapshot) {
                  String userNickname = "사용자";
                  String profileImg = 'https://picsum.photos/100';

                  if (snapshot.hasData && snapshot.data!.exists) {
                    var userData = snapshot.data!.data() as Map<String, dynamic>;
                    userNickname = userData['nickName'] ?? "이름없음";
                    profileImg = userData['profile_image_url'] ?? profileImg;
                  }

                  return Row(
                    children: [
                      CircleAvatar(radius: 20, backgroundImage: NetworkImage(profileImg)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userNickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Postdelete(
                                postId: widget.postId,
                                initialData: widget.postData,
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          side: const BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("수정/삭제", style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 2. 메인 이미지
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(widget.imageUrl, width: double.infinity, height: 300, fit: BoxFit.cover),
              ),
            ),

            // 3. 본문 섹션
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildInfoChip(Icons.bookmark, widget.postData['board_type'] ?? "일반", Colors.blue[50]!, Colors.blue[600]!),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.location_on, "인천 부평구", Colors.grey[100]!, Colors.grey[600]!),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.postData['content'] ?? "내용이 없습니다.",
                    style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),

            // 🔥 4. 실시간 댓글 목록 (StreamBuilder 사용)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Text("댓글", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('cdate', descending: false) // 오래된 순서대로 (아래로 쌓임)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text("오류가 발생했습니다.");
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("첫 댓글을 남겨보세요!", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var comment = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 15)),
                      title: Text(comment['content'] ?? ""),
                      subtitle: Text(
                        comment['cdate'] != null
                            ? DateFormat('MM.dd HH:mm').format((comment['cdate'] as Timestamp).toDate())
                            : "",
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                );
              },
            ),

            // 5. 댓글 입력창
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: "댓글을 입력해주세요",
                        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _addComment, // 댓글 저장 함수 연결
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}