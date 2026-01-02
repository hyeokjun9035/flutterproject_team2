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


  Map<String, dynamic>? _currentPostData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.postData.isEmpty) {
      _loadPostData();
    } else {
      _currentPostData = widget.postData;
    }
  }


  Future<void> _loadPostData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var doc = await FirebaseFirestore.instance
          .collection('community')
          .doc(widget.postId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _currentPostData = doc.data();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("존재하지 않는 게시글입니다.")),
        );
      }
    } catch (e) {
      debugPrint("데이터 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    // 1. 데이터를 가져오는 중일 때
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. 데이터 로드 실패 혹은 게시글이 없을 때
    if (_currentPostData == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text("게시글 정보를 불러올 수 없습니다.")),
      );
    }


    final data = _currentPostData!;

    // 날짜 포맷팅
    String dateStr = "날짜 정보 없음";
    if (data['createdAt'] != null) {
      DateTime dt = (data['createdAt'] as Timestamp).toDate();
      dateStr = DateFormat('yyyy.MM.dd HH:mm').format(dt);
    }

    // 작성자 정보
    final author = data['author'] as Map<String, dynamic>? ?? {};
    final String nickName = author['nickName'] ?? author['name'] ?? "익명";
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
        title: const Text("게시글 확인",
            style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. 작성자 프로필 영역 ---
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
                        // 수정/삭제 버튼 (작성자 본인 확인 로직 필요 시 추가)
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Postdelete(postId: widget.postId, initialData: data),
                            ),
                          ),
                          child: const Text("수정/삭제", style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // --- 2. 제목 영역 ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Text(
                      data['title'] ?? "제목 없음",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // --- 3. 본문 영역 (Blocks 렌더링) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildContentBlocks(data),
                  ),

                  const SizedBox(height: 30),
                  const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F5)),

                  // --- 4. 댓글 목록 영역 ---
                  _buildCommentSection(),
                ],
              ),
            ),
          ),
          // --- 5. 댓글 입력 영역 ---
          _buildCommentInput(),
        ],
      ),
    );
  }


  Widget _buildContentBlocks(Map<String, dynamic> data) {
    List<dynamic> blocks = data['blocks'] ?? [];
    List<dynamic> images = data['images'] ?? [];
    List<dynamic> videoThumbs = data['videoThumbs'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        String type = block['t'] ?? 'text';
        var value = block['v'];

        if (type == 'text') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
            ),
          );
        } else if (type == 'image') {
          int index = value is int ? value : int.tryParse(value.toString()) ?? 0;
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
          int index = value is int ? value : int.tryParse(value.toString()) ?? 0;
          String? thumb = index < videoThumbs.length ? videoThumbs[index] : null;
          return _buildVideoItem(thumb);
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildVideoItem(String? thumbUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AspectRatio(
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
              radius: 25,
              backgroundColor: Colors.black54,
              child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text("댓글", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Text("첫 댓글을 작성해보세요.", style: TextStyle(color: Colors.grey, fontSize: 13)),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                var comment = docs[index].data() as Map<String, dynamic>;
                return ListTile(
                  leading: const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 15)),
                  title: Text(comment['content'] ?? "", style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    comment['cdate'] != null
                        ? DateFormat('MM.dd HH:mm').format((comment['cdate'] as Timestamp).toDate())
                        : "",
                    style: const TextStyle(fontSize: 11),
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
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: "댓글을 입력하세요...",
                hintStyle: const TextStyle(fontSize: 14),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _addComment,
            icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
          ),
        ],
      ),
    );
  }
}