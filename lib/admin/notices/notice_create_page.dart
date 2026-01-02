import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
          _selectedImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      debugPrint('이미지 선택 오류: $e');
    }
  }

  Future<void> _pickVideo() async {
    if (!mounted) return;
    final List<File>? selectedVideos = await showDialog<List<File>>(
      context: context,
      builder: (context) => const _VideoSelectionDialog(),
    );
    if (selectedVideos != null && selectedVideos.isNotEmpty) {
      setState(() {
        for (var video in selectedVideos) {
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
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_img_$i.jpg';
      final ref = FirebaseStorage.instance.ref().child('notice_images/$fileName');
      await ref.putFile(file);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<Map<String, List<String>>> _uploadVideosAndThumbs(List<File> files) async {
    final List<String> videoUrls = [];
    final List<String> thumbUrls = [];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoName = '${timestamp}_$i.mp4';
      final vRef = FirebaseStorage.instance.ref().child('community/videos/$videoName');
      await vRef.putFile(file, SettableMetadata(contentType: 'video/mp4'));
      videoUrls.add(await vRef.getDownloadURL());
      try {
        final thumbBytes = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 900,
          quality: 75,
        );
        if (thumbBytes != null) {
          final tempDir = await getTemporaryDirectory();
          final thumbFile = File(p.join(tempDir.path, '${timestamp}_thumb_$i.jpg'));
          await thumbFile.writeAsBytes(thumbBytes);
          final tRef = FirebaseStorage.instance.ref().child('community/video_thumbs/${timestamp}_$i.jpg');
          await tRef.putFile(thumbFile, SettableMetadata(contentType: 'image/jpeg'));
          thumbUrls.add(await tRef.getDownloadURL());
        } else {
          thumbUrls.add('');
        }
      } catch (e) {
        thumbUrls.add('');
      }
    }
    return {'videos': videoUrls, 'thumbs': thumbUrls};
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목/내용을 입력하세요')));
      return;
    }

    setState(() => _saving = true);

    try {
      final imageUrls = await _uploadImagesToStorage(_selectedImages);
      final videoData = await _uploadVideosAndThumbs(_selectedVideos);
      final videoUrls = videoData['videos']!;
      final thumbUrls = videoData['thumbs']!;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보 없음');
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userSnap.data() ?? {};
      final myNickName = (userData['nickName'] ?? userData['nickname'] ?? '관리자').toString();

      // ✅ 일반 게시글과 동일한 데이터 구조로 저장
      await FirebaseFirestore.instance.collection('community').add({
        'category': '공지사항', // board_type 대신 category 사용
        'title': title,
        'plain': content,
        'user_nickname': myNickName,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtClient': DateTime.now().millisecondsSinceEpoch,
        
        'author': {
          'uid': user.uid,
          'email': user.email ?? '',
          'name': userData['name'] ?? '',
          'nickName': myNickName,
          'profile_image_url': userData['profile_image_url'] ?? '',
        },

        'blocks': [], // 공지사항은 blocks를 빈 배열로 유지 (필요 시 추후 에디터 도입 가능)
        'images': imageUrls,
        'videos': videoUrls,
        'videoThumbs': thumbUrls,

        'commentCount': 0,
        'likeCount': 0,
        'viewCount': 0,

        // 데이터 일관성을 위한 기본값 (공지사항은 위치/날씨 정보가 보통 없으므로 null 또는 기본값)
        'place': null,
        'weather': null,
        'air': null,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공지 등록 완료')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
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
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('등록'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _contentCtrl, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const Text('-게시글 사진/영상', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(onPressed: _pickImages, icon: const Icon(Icons.photo_library_outlined, size: 30, color: Colors.black87)),
                IconButton(onPressed: _pickVideo, icon: const Icon(Icons.videocam_outlined, size: 30, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: _selectedImages.length + _selectedVideos.length,
                itemBuilder: (context, i) {
                  if (i < _selectedImages.length) {
                    return Stack(
                      children: [
                        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_selectedImages[i], fit: BoxFit.cover))),
                        Positioned(right: 4, top: 4, child: GestureDetector(onTap: () => setState(() => _selectedImages.removeAt(i)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
                      ],
                    );
                  } else {
                    final vIdx = i - _selectedImages.length;
                    return _VideoThumbnailWidget(videoFile: _selectedVideos[vIdx], onRemove: () => setState(() => _selectedVideos.removeAt(vIdx)));
                  }
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _VideoSelectionDialog extends StatefulWidget {
  const _VideoSelectionDialog();
  @override
  State<_VideoSelectionDialog> createState() => _VideoSelectionDialogState();
}

class _VideoSelectionDialogState extends State<_VideoSelectionDialog> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _tempVideos = [];
  Future<void> _selectVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) setState(() => _tempVideos.add(File(video.path)));
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('동영상 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _selectVideo, icon: const Icon(Icons.add), label: const Text('동영상 추가')),
            if (_tempVideos.isNotEmpty)
              Flexible(child: ListView.builder(shrinkWrap: true, itemCount: _tempVideos.length, itemBuilder: (context, index) => ListTile(dense: true, title: Text(_tempVideos[index].path.split('/').last, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20), onPressed: () => setState(() => _tempVideos.removeAt(index)))))),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), ElevatedButton(onPressed: () => Navigator.pop(context, _tempVideos), child: const Text('확인'))]),
          ],
        ),
      ),
    );
  }
}

class _VideoThumbnailWidget extends StatelessWidget {
  final File videoFile;
  final VoidCallback onRemove;
  const _VideoThumbnailWidget({required this.videoFile, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.black12), child: FutureBuilder<Uint8List?>(future: VideoThumbnail.thumbnailData(video: videoFile.path, imageFormat: ImageFormat.JPEG, maxWidth: 300, quality: 75), builder: (context, snapshot) {
          if (snapshot.hasData) return Stack(fit: StackFit.expand, children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(snapshot.data!, fit: BoxFit.cover)), Center(child: Container(decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: Colors.white, size: 24)))]);
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }))),
        Positioned(right: 4, top: 4, child: GestureDetector(onTap: onRemove, child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
      ],
    );
  }
}
