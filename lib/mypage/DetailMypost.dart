import 'package:flutter/material.dart';
import 'package:flutter_project/mypage/postDelete.dart'; // 경로 확인 필요
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
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('community')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'user_id': user.uid,
        'content': commentText,
        'cdate': FieldValue.serverTimestamp(),
      });
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      debugPrint("댓글 저장 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 데이터 구조 변경 반영: cdate -> createdAt
    String dateStr = "";
    if (widget.postData['createdAt'] != null) {
      DateTime dt = (widget.postData['createdAt'] as Timestamp).toDate();
      dateStr = DateFormat('yyyy.MM.dd HH:mm').format(dt);
    }

    // ✅ author 맵에서 정보 추출
    final author = widget.postData['author'] as Map<String, dynamic>? ?? {};
    final String nickName = author['nickName'] ?? "익명";
    final String profileImg = author['profile_image_url'] ?? 'https://via.placeholder.com/150';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("게시글 확인", style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold)),
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
              child: Row(
                children: [
                  CircleAvatar(radius: 20, backgroundImage: NetworkImage(profileImg)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nickName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Postdelete(postId: widget.postId, initialData: widget.postData),
                      ),
                    ),
                    child: const Text("수정/삭제", style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 2. 제목 영역
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.postData['title'] ?? "제목 없음",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            // 3. 본문 렌더링 (blocks 순회)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildContentBlocks(),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F5)),

            // 4. 댓글 목록
            _buildCommentSection(),

            // 5. 댓글 입력창
            _buildCommentInput(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ 핵심: blocks 리스트를 타입별로 그려주는 함수
  Widget _buildContentBlocks() {
    List<dynamic> blocks = widget.postData['blocks'] ?? [];
    List<dynamic> images = widget.postData['images'] ?? [];
    List<dynamic> videos = widget.postData['videos'] ?? [];
    List<dynamic> videoThumbs = widget.postData['videoThumbs'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        String type = block['t'] ?? 'text';
        var value = block['v'];

        if (type == 'text') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(value.toString(), style: const TextStyle(fontSize: 15, height: 1.6)),
          );
        } else if (type == 'image') {
          int index = value is int ? value : 0;
          if (index < images.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(images[index], width: double.infinity, fit: BoxFit.cover),
              ),
            );
          }
        } else if (type == 'video') {
          int index = value is int ? value : 0;
          String? thumb = index < videoThumbs.length ? videoThumbs[index] : null;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildVideoPreview(thumb),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  // 비디오 미리보기 (재생기는 별도 구현 필요)
  Widget _buildVideoPreview(String? thumbUrl) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              image: thumbUrl != null ? DecorationImage(image: NetworkImage(thumbUrl), fit: BoxFit.cover) : null,
            ),
          ),
          const CircleAvatar(
            backgroundColor: Colors.black54,
            child: Icon(Icons.play_arrow, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text("댓글", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('community')
              .doc(widget.postId)
              .collection('comments')
              .orderBy('cdate', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final docs = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var comment = docs[index].data() as Map<String, dynamic>;
                return ListTile(
                  leading: const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 15)),
                  title: Text(comment['content'] ?? ""),
                  subtitle: Text(
                    comment['cdate'] != null ? DateFormat('MM.dd HH:mm').format((comment['cdate'] as Timestamp).toDate()) : "",
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: "댓글을 입력하세요...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          IconButton(onPressed: _addComment, icon: const Icon(Icons.send, color: Colors.blueAccent)),
        ],
      ),
    );
  }
}