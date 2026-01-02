import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/notice_repository.dart';

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
  final repo = NoticeRepository();
  final ImagePicker _picker = ImagePicker();
  
  // ✅ 기존 이미지/동영상 URL
  List<String> _existingImageUrls = [];
  List<String> _existingVideoUrls = [];
  List<String> _existingVideoThumbs = []; // ✅ 동영상 썸네일 URL
  
  // ✅ 새로 추가할 이미지/동영상 파일
  List<File> _newImages = [];
  List<File> _newVideos = [];
  
  // ✅ 삭제할 이미지/동영상 URL
  List<String> _imagesToDelete = [];
  List<String> _videosToDelete = [];
  
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = (widget.initial['title'] ?? '').toString();
    _contentCtrl.text = (widget.initial['plain'] ?? widget.initial['content'] ?? '').toString();
    
    // ✅ 기존 이미지/동영상 URL 로드
    final imagesRaw = widget.initial['images'] ?? widget.initial['image_urls'];
    _existingImageUrls = (imagesRaw is List) 
        ? imagesRaw.whereType<String>().toList() 
        : [];
    
    final videosRaw = widget.initial['videos'];
    _existingVideoUrls = (videosRaw is List) 
        ? videosRaw.whereType<String>().toList() 
        : [];
    
    // ✅ 기존 동영상 썸네일 URL 로드
    final videoThumbsRaw = widget.initial['videoThumbs'];
    _existingVideoThumbs = (videoThumbsRaw is List) 
        ? videoThumbsRaw.whereType<String>().toList() 
        : [];
  }

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
          _newImages.addAll(images.map((x) => File(x.path)));
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
          if (!_newVideos.any((v) => v.path == video.path)) {
            _newVideos.add(video);
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
      final ref = FirebaseStorage.instance.ref().child('notice_images/$fileName');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<Map<String, List<String>>> _uploadVideosToStorage(List<File> files) async {
    final List<String> urls = [];
    final List<String> thumbUrls = [];
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$i.mp4';
      
      // 동영상 업로드
      final ref = FirebaseStorage.instance.ref().child('community/videos/$fileName');
      await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
      final url = await ref.getDownloadURL();
      urls.add(url);
      
      // 썸네일 생성 및 업로드
      String thumbUrl = '';
      try {
        final thumbBytes = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 900,
          quality: 75,
        );
        
        if (thumbBytes != null) {
          // ✅ 임시 파일로 저장 후 업로드
          final tempDir = await getTemporaryDirectory();
          final thumbPath = p.join(
            tempDir.path,
            '${timestamp}_${i}_thumb.jpg',
          );
          final thumbFile = File(thumbPath);
          await thumbFile.writeAsBytes(thumbBytes, flush: true);
          
          final thumbFileName = '${timestamp}_${i}_thumb.jpg';
          final thumbRef = FirebaseStorage.instance.ref().child('community/video_thumbs/$thumbFileName');
          await thumbRef.putFile(thumbFile, SettableMetadata(contentType: 'image/jpeg'));
          thumbUrl = await thumbRef.getDownloadURL();
          
          // ✅ 임시 파일 삭제
          try {
            await thumbFile.delete();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('썸네일 생성 오류: $e');
      }
      thumbUrls.add(thumbUrl);
    }
    
    return {'urls': urls, 'thumbs': thumbUrls};
  }

  Future<void> _deleteStorageFiles(List<String> urls) async {
    for (final url in urls) {
      try {
        if (url.startsWith('http')) {
          await FirebaseStorage.instance.refFromURL(url).delete();
        }
      } catch (e) {
        debugPrint('파일 삭제 오류: $e');
      }
    }
  }

  Future<void> _save() async {
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
      // 1️⃣ 새 이미지 업로드
      final newImageUrls = _newImages.isEmpty
          ? <String>[]
          : await _uploadImagesToStorage(_newImages);

      // 2️⃣ 새 동영상 업로드 (썸네일 포함)
      final newVideoData = _newVideos.isEmpty
          ? {'urls': <String>[], 'thumbs': <String>[]}
          : await _uploadVideosToStorage(_newVideos);
      final newVideoUrls = newVideoData['urls'] as List<String>;
      final newVideoThumbs = newVideoData['thumbs'] as List<String>;

      // 3️⃣ 삭제할 파일 삭제
      await _deleteStorageFiles(_imagesToDelete);
      await _deleteStorageFiles(_videosToDelete);
      
      // 삭제할 동영상의 썸네일도 삭제
      final thumbsToDelete = <String>[];
      for (int i = 0; i < _existingVideoUrls.length; i++) {
        if (_videosToDelete.contains(_existingVideoUrls[i]) && 
            i < _existingVideoThumbs.length && 
            _existingVideoThumbs[i].isNotEmpty) {
          thumbsToDelete.add(_existingVideoThumbs[i]);
        }
      }
      await _deleteStorageFiles(thumbsToDelete);

      // 4️⃣ 최종 이미지/동영상 URL 리스트 구성
      final finalImageUrls = [
        ..._existingImageUrls.where((url) => !_imagesToDelete.contains(url)),
        ...newImageUrls,
      ];
      
      final finalVideoUrls = [
        ..._existingVideoUrls.where((url) => !_videosToDelete.contains(url)),
        ...newVideoUrls,
      ];
      
      // ✅ 최종 동영상 썸네일 URL 리스트 구성
      final finalVideoThumbs = <String>[];
      for (int i = 0; i < _existingVideoUrls.length; i++) {
        if (!_videosToDelete.contains(_existingVideoUrls[i]) && 
            i < _existingVideoThumbs.length) {
          finalVideoThumbs.add(_existingVideoThumbs[i]);
        }
      }
      finalVideoThumbs.addAll(newVideoThumbs);

      // 5️⃣ Firestore 업데이트
      await FirebaseFirestore.instance.collection('community').doc(widget.docId).update({
        'title': title,
        'plain': content,
        'content': content,  // 구 형식 호환성
        'images': finalImageUrls,
        'videos': finalVideoUrls,
        'videoThumbs': finalVideoThumbs, // ✅ 썸네일 URL도 업데이트
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정 완료')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지 수정'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
            
            // ✅ 기존 이미지 표시
            if (_existingImageUrls.isNotEmpty) ...[
              const Text('기존 이미지', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _existingImageUrls.length,
                itemBuilder: (_, i) {
                  final url = _existingImageUrls[i];
                  final isDeleted = _imagesToDelete.contains(url);
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Opacity(
                          opacity: isDeleted ? 0.3 : 1.0,
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isDeleted) {
                                _imagesToDelete.remove(url);
                              } else {
                                _imagesToDelete.add(url);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDeleted ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDeleted ? Icons.undo : Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            
            // ✅ 새로 추가한 이미지 표시
            if (_newImages.isNotEmpty) ...[
              const Text('새 이미지', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _newImages.length,
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_newImages[i], fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _newImages.removeAt(i);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // ✅ 기존 동영상 표시
            if (_existingVideoUrls.isNotEmpty) ...[
              const Text('기존 동영상', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingVideoUrls.length,
                  itemBuilder: (context, index) {
                    final url = _existingVideoUrls[index];
                    // ✅ 동영상 URL과 같은 인덱스의 썸네일 URL 가져오기
                    final thumbUrl = index < _existingVideoThumbs.length 
                        ? _existingVideoThumbs[index] 
                        : null;
                    final isDeleted = _videosToDelete.contains(url);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _VideoThumbnailWidget(
                        videoUrl: url,
                        thumbnailUrl: thumbUrl, // ✅ 썸네일 URL 전달
                        isDeleted: isDeleted,
                        onToggleDelete: () {
                          setState(() {
                            if (isDeleted) {
                              _videosToDelete.remove(url);
                            } else {
                              _videosToDelete.add(url);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // ✅ 새로 추가한 동영상 표시
            if (_newVideos.isNotEmpty) ...[
              const Text('새 동영상', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newVideos.length,
                  itemBuilder: (context, index) {
                    final video = _newVideos[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _VideoThumbnailWidget(
                        videoFile: video,
                        onRemove: () {
                          setState(() {
                            _newVideos.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // ✅ 이미지/동영상 추가 버튼
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
                      tooltip: '사진 추가',
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo_library_outlined, size: 30),
                    ),
                    IconButton(
                      tooltip: '동영상 추가',
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam_outlined, size: 30),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ 동영상 썸네일 위젯 (수정 페이지용)
class _VideoThumbnailWidget extends StatelessWidget {
  final File? videoFile;
  final String? videoUrl;
  final String? thumbnailUrl; // ✅ 썸네일 URL 추가
  final bool isDeleted;
  final VoidCallback? onToggleDelete;
  final VoidCallback? onRemove;

  const _VideoThumbnailWidget({
    this.videoFile,
    this.videoUrl,
    this.thumbnailUrl, // ✅ 썸네일 URL 파라미터 추가
    this.isDeleted = false,
    this.onToggleDelete,
    this.onRemove,
  });

  Future<Uint8List?> _getThumbnailFromLocal(String path) async {
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

  Future<Uint8List?> _getThumbnailFromNetwork(String url) async {
    try {
      // ✅ 네트워크 URL에서 썸네일 생성 (video_thumbnail은 로컬 파일만 지원하므로 HTTP 요청으로 대체)
      // 실제로는 서버에서 썸네일을 제공하거나, 클라이언트에서 다운로드 후 생성해야 함
      // 여기서는 썸네일 URL이 있으면 그것을 사용하고, 없으면 기본 아이콘 표시
      return null;
    } catch (e) {
      debugPrint('네트워크 썸네일 생성 오류: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocalFile = videoFile != null;
    
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
            child: isLocalFile
                ? FutureBuilder<Uint8List?>(
                    future: _getThumbnailFromLocal(videoFile!.path),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      if (snapshot.hasData && snapshot.data != null) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(snapshot.data!, fit: BoxFit.cover),
                            Container(
                              color: Colors.black.withOpacity(0.3),
                              child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 30),
                            ),
                          ],
                        );
                      }
                      return const Icon(Icons.videocam, size: 40);
                    },
                  )
                : thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          // ✅ 썸네일 URL이 있으면 네트워크 이미지로 표시
                          Image.network(
                            thumbnailUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.black12,
                                child: const Icon(Icons.videocam, size: 40),
                              );
                            },
                          ),
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 30),
                          ),
                        ],
                      )
                    : Container(
                        // ✅ 썸네일이 없으면 기본 아이콘 표시
                        color: Colors.black12,
                        child: const Icon(Icons.videocam, size: 40),
                      ),
          ),
        ),
        if (isDeleted)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('삭제 예정', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove ?? onToggleDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDeleted ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDeleted ? Icons.undo : Icons.close,
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

// ✅ 동영상 선택 다이얼로그 (수정 페이지에서도 사용)
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
            ElevatedButton.icon(
              onPressed: _selectVideo,
              icon: const Icon(Icons.add),
              label: const Text('동영상 추가'),
            ),
            const SizedBox(height: 16),
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

// ✅ 동영상 리스트 아이템 위젯
class _VideoListItemWidget extends StatelessWidget {
  final File videoFile;
  final VoidCallback onRemove;

  const _VideoListItemWidget({
    required this.videoFile,
    required this.onRemove,
  });

  String _getVideoFileName(File file) {
    final fileName = file.path.split('/').last;
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
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(snapshot.data!, fit: BoxFit.cover),
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 24),
                        ),
                      ],
                    );
                  }
                  return const Icon(Icons.videocam, size: 30);
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getVideoFileName(videoFile),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    videoFile.path.split('/').last,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
