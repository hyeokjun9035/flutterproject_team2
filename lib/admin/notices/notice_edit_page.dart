import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class NoticeEditPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initial;

  const NoticeEditPage({super.key, required this.docId, required this.initial});

  @override
  State<NoticeEditPage> createState() => _NoticeEditPageState();
}

class _NoticeEditPageState extends State<NoticeEditPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  List<dynamic> _allMedia = []; 
  List<String> _videoThumbs = []; 
  
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = (widget.initial['title'] ?? '').toString();
    _contentCtrl.text = (widget.initial['plain'] ?? widget.initial['content'] ?? '').toString();
    
    final images = (widget.initial['images'] as List?)?.cast<String>() ?? [];
    final videos = (widget.initial['videos'] as List?)?.cast<String>() ?? [];
    _videoThumbs = (widget.initial['videoThumbs'] as List?)?.cast<String>() ?? [];
    
    _allMedia = [...images, ...videos];
  }

  bool _isVideo(dynamic item) {
    if (item is File) return item.path.toLowerCase().endsWith('.mp4');
    if (item is String) return item.toLowerCase().contains('.mp4') || item.toLowerCase().contains('videos%2F');
    return false;
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _allMedia.addAll(images.map((x) => File(x.path))));
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => _allMedia.add(File(video.path)));
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목과 내용을 입력해주세요.')));
      return;
    }

    setState(() => _saving = true);

    try {
      List<String> finalImages = [];
      List<String> finalVideos = [];
      List<String> finalThumbs = [];

      Map<String, String> thumbMap = {};
      final oldVideos = (widget.initial['videos'] as List?)?.cast<String>() ?? [];
      for(int i=0; i<oldVideos.length; i++) {
        if (i < _videoThumbs.length) thumbMap[oldVideos[i]] = _videoThumbs[i];
      }

      int fileCount = 0;
      for (var item in _allMedia) {
        if (item is String) {
          if (_isVideo(item)) {
            finalVideos.add(item);
            finalThumbs.add(thumbMap[item] ?? '');
          } else {
            finalImages.add(item);
          }
        } else if (item is File) {
          fileCount++;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final uniqueName = '${timestamp}_$fileCount';

          if (_isVideo(item)) {
            final vRef = FirebaseStorage.instance.ref().child('community/videos/$uniqueName.mp4');
            await vRef.putFile(item, SettableMetadata(contentType: 'video/mp4'));
            final vUrl = await vRef.getDownloadURL();
            finalVideos.add(vUrl);

            final thumbBytes = await VideoThumbnail.thumbnailData(video: item.path, imageFormat: ImageFormat.JPEG, maxWidth: 500);
            if (thumbBytes != null) {
              final tRef = FirebaseStorage.instance.ref().child('community/video_thumbs/$uniqueName.jpg');
              await tRef.putData(thumbBytes, SettableMetadata(contentType: 'image/jpeg'));
              finalThumbs.add(await tRef.getDownloadURL());
            } else {
              finalThumbs.add('');
            }
          } else {
            final iRef = FirebaseStorage.instance.ref().child('notice_images/$uniqueName.jpg');
            await iRef.putFile(item);
            final iUrl = await iRef.getDownloadURL();
            finalImages.add(iUrl);
          }
        }
      }

      // ✅ 핵심: blocks를 []로 강제 업데이트하여Fallback 로직이 작동하게 함
      await FirebaseFirestore.instance.collection('community').doc(widget.docId).update({
        'title': _titleCtrl.text.trim(),
        'plain': _contentCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'images': finalImages,
        'videos': finalVideos,
        'videoThumbs': finalThumbs,
        'blocks': [], 
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('공지 수정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('완료', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _contentCtrl, minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            const Text('사진/영상 관리 (3열)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(onPressed: _pickImages, icon: const Icon(Icons.photo_library_outlined, size: 28)),
                IconButton(onPressed: _pickVideo, icon: const Icon(Icons.videocam_outlined, size: 28)),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: _allMedia.length,
              itemBuilder: (context, index) {
                final item = _allMedia[index];
                final isVideo = _isVideo(item);
                
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildPreview(item, isVideo),
                      ),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _allMedia.removeAt(index)),
                        child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                      ),
                    ),
                    if (isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(dynamic item, bool isVideo) {
    if (item is String) {
      if (isVideo) {
        final idx = (widget.initial['videos'] as List?)?.indexOf(item) ?? -1;
        if (idx != -1 && idx < _videoThumbs.length && _videoThumbs[idx].isNotEmpty) {
          return Image.network(_videoThumbs[idx], fit: BoxFit.cover);
        }
        return Container(color: Colors.black12, child: const Icon(Icons.videocam));
      }
      return Image.network(item, fit: BoxFit.cover);
    } else if (item is File) {
      if (isVideo) {
        return FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(video: item.path, imageFormat: ImageFormat.JPEG, maxWidth: 200),
          builder: (context, snap) => snap.hasData ? Image.memory(snap.data!, fit: BoxFit.cover) : Container(color: Colors.black12),
        );
      }
      return Image.file(item, fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }
}
