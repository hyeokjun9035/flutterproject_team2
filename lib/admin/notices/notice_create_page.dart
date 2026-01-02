import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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

  // ✅ 동영상 선택 (사진처럼 여러 개 선택 후 한 번에 추가)
  Future<void> _pickVideo() async {
    if (!mounted) return;
    
    // ✅ 동영상 선택 다이얼로그 표시
    final List<File>? selectedVideos = await showDialog<List<File>>(
      context: context,
      builder: (context) => const _VideoSelectionDialog(),
    );
    
    // ✅ 다이얼로그에서 확인을 누르면 선택한 동영상들을 한 번에 추가
    if (selectedVideos != null && selectedVideos.isNotEmpty) {
      setState(() {
        for (var video in selectedVideos) {
          // 중복 방지
          if (!_selectedVideos.any((v) => v.path == video.path)) {
            _selectedVideos.add(video);
          }
        }
      });
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.videocam, size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(
                          '동영상 ${_selectedVideos.length}개 선택됨',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ✅ 선택된 동영상 썸네일 표시
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedVideos.length,
                        itemBuilder: (context, index) {
                          final video = _selectedVideos[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _VideoThumbnailWidget(
                              videoFile: video,
                              onRemove: () {
                                setState(() {
                                  _selectedVideos.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
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

// ✅ 동영상 선택 다이얼로그
class _VideoSelectionDialog extends StatefulWidget {
  const _VideoSelectionDialog();

  @override
  State<_VideoSelectionDialog> createState() => _VideoSelectionDialogState();
}

class _VideoSelectionDialogState extends State<_VideoSelectionDialog> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _tempVideos = [];

  Future<void> _selectVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final file = File(video.path);
        // 중복 방지
        if (!_tempVideos.any((v) => v.path == file.path)) {
          setState(() {
            _tempVideos.add(file);
          });
        }
      }
    } catch (e) {
      debugPrint('동영상 선택 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '동영상 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // ✅ 동영상 추가 버튼
            ElevatedButton.icon(
              onPressed: _selectVideo,
              icon: const Icon(Icons.add),
              label: const Text('동영상 추가'),
            ),
            const SizedBox(height: 16),
            // ✅ 선택된 동영상 목록
            if (_tempVideos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '동영상을 선택해주세요',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _tempVideos.length,
                  itemBuilder: (context, index) {
                    final video = _tempVideos[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _VideoListItemWidget(
                        videoFile: video,
                        onRemove: () {
                          setState(() {
                            _tempVideos.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            // ✅ 확인/취소 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _tempVideos.isEmpty
                      ? null
                      : () => Navigator.pop(context, _tempVideos),
                  child: Text('추가 (${_tempVideos.length}개)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ 동영상 썸네일 위젯 (메인 화면용)
class _VideoThumbnailWidget extends StatelessWidget {
  final File videoFile;
  final VoidCallback onRemove;

  const _VideoThumbnailWidget({
    required this.videoFile,
    required this.onRemove,
  });

  String _getVideoFileName(File file) {
    final fileName = file.path.split('/').last;
    // 파일명이 너무 길면 자르기
    if (fileName.length > 15) {
      return '${fileName.substring(0, 12)}...';
    }
    return fileName;
  }

  Future<Uint8List?> _getThumbnail(String path) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 75,
      );
      return bytes;
    } catch (e) {
      debugPrint('썸네일 생성 오류: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Uint8List?>(
              future: _getThumbnail(videoFile.path),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      ),
                      // 재생 아이콘 오버레이
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  );
                }
                // 썸네일 생성 실패 시 기본 아이콘
                return const Icon(Icons.videocam, size: 40);
              },
            ),
          ),
        ),
        // 파일명 표시
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(
              _getVideoFileName(videoFile),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // 삭제 버튼
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ 동영상 리스트 아이템 위젯 (다이얼로그용)
class _VideoListItemWidget extends StatelessWidget {
  final File videoFile;
  final VoidCallback onRemove;

  const _VideoListItemWidget({
    required this.videoFile,
    required this.onRemove,
  });

  String _getVideoFileName(File file) {
    final fileName = file.path.split('/').last;
    // 확장자 제거하고 파일명만 표시
    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return nameWithoutExt;
  }

  Future<Uint8List?> _getThumbnail(String path) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 150,
        quality: 75,
      );
      return bytes;
    } catch (e) {
      debugPrint('썸네일 생성 오류: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 썸네일
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: FutureBuilder<Uint8List?>(
                future: _getThumbnail(videoFile.path),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    );
                  }
                  return const Icon(Icons.videocam, size: 30);
                },
              ),
            ),
          ),
          // 파일명
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getVideoFileName(videoFile),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    videoFile.path.split('/').last,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // 삭제 버튼
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
