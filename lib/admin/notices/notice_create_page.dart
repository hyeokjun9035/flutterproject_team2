import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoticeCreatePage extends StatefulWidget {
  const NoticeCreatePage({super.key});

  @override
  State<NoticeCreatePage> createState() => _NoticeCreatePageState();
}

class _NoticeCreatePageState extends State<NoticeCreatePage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images.map((x) => File(x.path)).toList();
        });
      }
    } catch (e) {
      debugPrint('이미지 선택 오류: $e');
    }
  }

// ✅ 동영상 선택 (누적 추가)
  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      final f = File(video.path);

      // ✅ 중복 방지(같은 파일 다시 선택하면 추가 안 함)
      final exists = _selectedVideos.any((v) => v.path == f.path);
      if (!exists) {
        setState(() {
          _selectedVideos.add(f); // ⭐ 여기서 누적 추가
        });
      }
    } catch (e) {
      debugPrint('동영상 선택 오류: $e');
    }
  }


  Future<List<String>> _uploadImagesToStorage(List<File> files) async {
    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      // ✅ 공지 이미지 폴더 (원하는 이름으로 바꿔도 됨)
      final ref = FirebaseStorage.instance.ref().child(
        'notice_images/$fileName',
      );

      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  // ✅ 동영상 업로드
  Future<List<String>> _uploadVideosToStorage(List<File> files) async {
    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.mp4';

      final ref = FirebaseStorage.instance.ref().child(
        'community/videos/$fileName',
      );

      await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));

      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목/내용을 입력하세요')));
      return;
    }

    setState(() => _saving = true);

    try {
      // 1️⃣ 이미지 업로드
      final imageUrls = _selectedImages.isEmpty
          ? <String>[]
          : await _uploadImagesToStorage(_selectedImages);

      // 1️⃣-2 동영상 업로드
      final videoUrls = _selectedVideos.isEmpty
          ? <String>[]
          : await _uploadVideosToStorage(_selectedVideos);

      // 2️⃣ 로그인 사용자
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보 없음');

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userSnap.data() ?? {};

      // 3️⃣ Firestore insert (⭐ 새 규칙 ⭐)
      await FirebaseFirestore.instance.collection('community').add({
        // ✅ 공지사항 핵심
        'category': '공지사항',

        // ✅ 게시글 기본
        'title': title,
        'plain': content,
        'images': imageUrls,
        'videos': videoUrls, // ✅ 여기 중요
        'blocks': [],

        // ✅ 작성 정보
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,

        // ✅ 작성자 정보 (map)
        'author': {
          'uid': user.uid,
          'email': user.email,
          'name': userData['name'] ?? '',
          'nickName': userData['nickName'] ?? '',
          'profile_image_url':
              userData['profile_image_url'] ??
              'https://example.com/default_avatar.png',
        },

        // ✅ 카운트류
        'commentCount': 0,
        'likeCount': 0,
        'viewCount': 0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공지 등록 완료')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('공지 등록'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('등록'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 제목
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ✅ 내용
            TextField(
              controller: _contentCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              '-게시글',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // ✅ 큰 이미지 미리보기(첫 번째 이미지)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.2),
                color: Colors.grey[100],
              ),
              child: _selectedImages.isEmpty
                  ? const Center(child: Text('사진을 올려주세요'))
                  : Image.file(_selectedImages[0], fit: BoxFit.cover),
            ),

            const SizedBox(height: 16),

            // ✅ 갤러리 + 카메라 아이콘 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '-갤러리',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: '사진 첨부',
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo_library_outlined, size: 30),
                    ),
                    IconButton(
                      tooltip: '동영상 첨부',
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam_outlined, size: 30),
                    ),
                  ],
                ),
              ],
            ),

            // ✅ 선택된 이미지 그리드
            _selectedImages.isEmpty
                ? Container(
                    height: 80,
                    alignment: Alignment.center,
                    child: const Text(
                      '-사진이 보이지 않으면 카메라 아이콘을 눌러주세요-',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _selectedImages.length,
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_selectedImages[i], fit: BoxFit.cover),
                    ),
                  ),
            // ✅ 선택된 동영상 표시
            if (_selectedVideos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      '동영상 ${_selectedVideos.length}개 선택됨',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
