import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Postdelete extends StatefulWidget {
  final String postId; // 문서 ID
  final Map<String, dynamic> initialData; // 기존 데이터

  const Postdelete({super.key, required this.postId, required this.initialData});

  @override
  State<Postdelete> createState() => _PostdeleteState();
}

class _PostdeleteState extends State<Postdelete> {
  late TextEditingController _contentController;
  late String _selectedBoard;
  bool _isProcessing = false; // 로딩 상태

  @override
  void initState() {
    super.initState();
    // 1. 전달받은 게시글 데이터로 초기값 세팅
    _contentController = TextEditingController(text: widget.initialData['content']);
    _selectedBoard = widget.initialData['board_type'] ?? "자유게시판";
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // --- 🔥 Firebase 삭제 로직 ---
  Future<void> _deletePost() async {
    setState(() => _isProcessing = true);
    try {
      // A. Storage 이미지 삭제 (이미지 URL 리스트가 있는 경우)
      List<dynamic> imageUrls = widget.initialData['image_urls'] ?? [];
      for (String url in imageUrls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          print("이미지 삭제 실패(경로가 없거나 이미 삭제됨): $e");
        }
      }

      // B. Firestore 문서 삭제
      await FirebaseFirestore.instance.collection('community').doc(widget.postId).delete();

      if (mounted) {
        Navigator.pop(context); // 팝업 닫기
        Navigator.pop(context); // 상세 페이지까지 닫기
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("게시글이 삭제되었습니다.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제 중 오류가 발생했습니다.")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 🔥 Firebase 수정 로직 ---
  Future<void> _updatePost() async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('community').doc(widget.postId).update({
        'content': _contentController.text,
        'board_type': _selectedBoard,
        'udate': FieldValue.serverTimestamp(), // 수정 시간 추가
      });

      if (mounted) {
        Navigator.pop(context); // 이전 페이지로 이동
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("수정이 완료되었습니다.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("수정 중 오류가 발생했습니다.")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("게시글을 삭제 하시겠습니까?", textAlign: TextAlign.center),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text("취소", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isProcessing ? null : _deletePost, // 로딩 중 클릭 방지
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("삭제하기", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 2. 랜덤 이미지 대신 실제 DB 이미지 URL 사용
    List<dynamic> imageUrls = widget.initialData['image_urls'] ?? [];
    String displayUrl = imageUrls.isNotEmpty ? imageUrls[0] : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소", style: TextStyle(color: Colors.black)),
        ),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _updatePost,
            child: const Text("수정하기", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 미리보기 (DB URL 사용)
            Container(
              width: 120,
              height: 100,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
              child: displayUrl.isNotEmpty
                  ? Image.network(displayUrl, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.image_not_supported)),
            ),
            const SizedBox(height: 20),

            // 카테고리 선택
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: Colors.black54)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedBoard,
                  items: const [
                    DropdownMenuItem(value: "자유게시판", child: Text("자유게시판")),
                    DropdownMenuItem(value: "비밀 게시판", child: Text("비밀 게시판")),
                    DropdownMenuItem(value: "공지사항", child: Text("공지사항")),
                    DropdownMenuItem(value: "필독", child: Text("필독")),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedBoard = value);
                  },
                ),
              ),
            ),

            // 위치 정보 (기존 데이터 사용)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.black54)),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 5),
                  Text(widget.initialData['location'] ?? "부평역"),
                ],
              ),
            ),

            // 본문 입력창 (Controller 연결)
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "내용을 입력하세요",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 삭제하기 버튼
            GestureDetector(
              onTap: () => _showDeleteDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("삭제하기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}