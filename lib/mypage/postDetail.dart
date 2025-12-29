import 'dart:io';
import 'package:flutter/material.dart';
// 1. Firebase 관련 임포트 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostDetail extends StatefulWidget {
  final List<File> images;

  const PostDetail({super.key, required this.images});

  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  final List<String> _boardList = ['자유게시판', '비밀게시판', '공지사항', '필독'];
  String? _selectedBoard;

  // 2. 텍스트 입력값을 가져오기 위한 컨트롤러 추가
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false; // 업로드 중 로딩 표시용

  // 3. Firebase 저장 함수 작성
  Future<void> _savePost() async {
    if (_selectedBoard == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("게시판을 선택해주세요!")));
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("내용을 입력해주세요!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      List<String> uploadedUrls = [];

      // A. Firebase Storage에 이미지 업로드
      for (var imageFile in widget.images) {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${widget.images.indexOf(imageFile)}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child('post_images').child(fileName);

        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
      }

      // B. Firestore에 게시글 데이터 저장 (설계해주신 필드명 적용)
      await FirebaseFirestore.instance.collection('community').add({
        'board_type': _selectedBoard,
        'title': '교통 제보', // 제목 필드가 UI에 따로 없어서 기본값으로 설정
        'content': _contentController.text.trim(),
        'user_id': user?.uid ?? '익명',
        'image_urls': uploadedUrls,
        'cdate': FieldValue.serverTimestamp(),
        'report_count': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("게시글이 등록되었습니다!")));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print("저장 중 에러 발생: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장에 실패했습니다.")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("뒤로", style: TextStyle(color: Colors.black, fontSize: 16)),
        ),
        actions: [
          // 4. 완료 버튼 클릭 시 저장 함수 호출
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton(
            onPressed: _savePost,
            child: const Text("완료", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 100,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                    child: widget.images.isNotEmpty
                        ? Image.file(widget.images[0], fit: BoxFit.cover)
                        : const Center(child: Text("이미지 없음")),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("현재 날씨", style: TextStyle(fontWeight: FontWeight.bold)),
                        Icon(Icons.wb_sunny_outlined, size: 30, color: Colors.orange),
                        Text("온도 : 5도, 미세먼지: 30ug/m^3", style: TextStyle(fontSize: 10)),
                        Text("습도:47% 바람: 2.6 m/s", style: TextStyle(fontSize: 10)),
                        Text("자동으로 입력됩니다.", style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.2)),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBoard,
                          hint: const Row(
                            children: [
                              Icon(Icons.bookmark_border, size: 20, color: Colors.black),
                              SizedBox(width: 10),
                              Text("올라갈 게시판을 선택해주세요.", style: TextStyle(fontSize: 14, color: Colors.black)),
                            ],
                          ),
                          isExpanded: true,
                          items: _boardList.map((String board) {
                            return DropdownMenuItem<String>(
                              value: board,
                              child: Text(board, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() => _selectedBoard = newValue);
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),
                    _buildFieldContent(
                      child: const Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 20),
                          SizedBox(width: 10),
                          Text("현재 위치 클릭시 현재위치 자동 입력 혹은 검색시", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),
                    _buildFieldContent(
                      child: const Text(
                        "현재 날씨: ☀️ 온도: 영상 5도, ☁️ 미세먼지 : 30ug/m^3, 💨 바람: 2.6m/s",
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),
                    Container(
                      height: 150,
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      child: TextField(
                        controller: _contentController, // 컨트롤러 연결
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: "게시글 내용을 입력해주세요.\nex) 00시 부평역 구간 정체 입니다. ㅠㅠ",
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldContent({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: child,
    );
  }
}