import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminNoticeWritePage extends StatefulWidget {
  const AdminNoticeWritePage({super.key});

  @override
  State<AdminNoticeWritePage> createState() => _AdminNoticeWritePageState();
}

class _AdminNoticeWritePageState extends State<AdminNoticeWritePage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];

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

  Future<List<String>> _uploadImagesToStorage(List<File> files) async {
    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      // ✅ 공지 이미지 폴더 (원하는 이름으로 바꿔도 됨)
      final ref = FirebaseStorage.instance.ref().child('notice_images/$fileName');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목/내용을 입력하세요')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // 1) 이미지 업로드 (있으면)
      final imageUrls = _selectedImages.isEmpty
          ? <String>[]
          : await _uploadImagesToStorage(_selectedImages);

      // 2) Firestore 저장 (community에 공지로 저장)
      await FirebaseFirestore.instance.collection('community').add({
        'board_type': '공지사항',
        'title': title,
        'content': content,
        'user_id': 'admin', // 너 구조상 일단 admin
        'image_urls': imageUrls,
        'cdate': FieldValue.serverTimestamp(),
        'report_count': 0,
        'is_notice': true,
        'status': 'active',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공지 등록 완료')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
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

            const Text('-게시글', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                const Text('-갤러리', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 30),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          ],
        ),
      ),
    );
  }
}
