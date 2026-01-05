import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

import '../headandputter/putter.dart';
import 'community_editor_widgets.dart'; // ✅ MiniQuillToolbar, LocalImageEmbedBuilder, LocalVideoEmbedBuilder, VideoBlockEmbed

class CommunityEdit extends StatefulWidget {
  final String docId;
  const CommunityEdit({super.key, required this.docId});

  @override
  State<CommunityEdit> createState() => _CommunityEditState();
}

class _CommunityEditState extends State<CommunityEdit> {
  late QuillController _editorController;
  final TextEditingController _title = TextEditingController();
  bool _loading = true;

  // 커서 위치 기억(새글에서 쓰던 로직)
  int _lastValidOffset = 0;

  final ImagePicker _picker = ImagePicker();

  // 비디오 미리보기(로컬)
  Future<void> _openVideoPlayerSheet({
    required String path,
    required String title,
  }) async {
    if (!File(path).existsSync()) return;

    final vp = VideoPlayerController.file(File(path));
    await vp.initialize();

    final chewie = ChewieController(
      videoPlayerController: vp,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowPlaybackSpeedChanging: true,
    );

    if (!mounted) {
      chewie.dispose();
      vp.dispose();
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: vp.value.aspectRatio,
                      child: Chewie(controller: chewie),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    chewie.dispose();
    vp.dispose();
  }

  // ✅ 이미지 삽입(로컬 경로)
  void _insertImageIntoEditor(String imagePath) {
    final sel = _editorController.selection;
    final index = sel.baseOffset >= 0 ? sel.baseOffset : _lastValidOffset;
    final length = (sel.baseOffset >= 0 && sel.extentOffset >= 0)
        ? (sel.extentOffset - sel.baseOffset)
        : 0;

    if (length > 0) _editorController.replaceText(index, length, '', null);

    _editorController.replaceText(index, 0, BlockEmbed.image(imagePath), null);
    _editorController.replaceText(index + 1, 0, '\n', null);

    _editorController.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      ChangeSource.local,
    );
  }

  // ✅ 비디오 삽입(로컬 경로 + 이름)
  void _insertVideoIntoEditor({required String videoPath, required String originalName}) {
    final sel = _editorController.selection;
    final index = sel.baseOffset >= 0 ? sel.baseOffset : _lastValidOffset;
    final length = (sel.baseOffset >= 0 && sel.extentOffset >= 0)
        ? (sel.extentOffset - sel.baseOffset)
        : 0;

    if (length > 0) _editorController.replaceText(index, length, '', null);

    final payload = jsonEncode({'path': videoPath, 'name': originalName});

    _editorController.replaceText(
      index,
      0,
      BlockEmbed.custom(VideoBlockEmbed(payload)),
      null,
    );
    _editorController.replaceText(index + 1, 0, '\n', null);

    _editorController.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      ChangeSource.local,
    );
  }

  Future<String> _ensureLocalPath(XFile xf) async {
    final dir = await getTemporaryDirectory();
    final origName = (xf.name.isNotEmpty) ? xf.name : 'video.mp4';
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$origName';
    final outPath = p.join(dir.path, safeName);

    await File(outPath).writeAsBytes(await xf.readAsBytes(), flush: true);
    return outPath;
  }

  Future<void> _pickFromGalleryAndInsert() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
      if (!mounted) return;
      for (final f in files) {
        _insertImageIntoEditor(f.path);
      }
    } catch (_) {}
  }

  Future<void> _pickFromCameraAndInsert() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (file != null) _insertImageIntoEditor(file.path);
    } catch (_) {}
  }

  Future<void> _pickVideoFromGalleryAndInsert() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (!mounted || file == null) return;

    final localPath = await _ensureLocalPath(file);
    _insertVideoIntoEditor(videoPath: localPath, originalName: file.name);
  }

  Future<void> _pickVideoFromCameraAndInsert() async {
    final file = await _picker.pickVideo(source: ImageSource.camera);
    if (!mounted || file == null) return;

    final localPath = await _ensureLocalPath(file);
    _insertVideoIntoEditor(
      videoPath: localPath,
      originalName: file.name.isNotEmpty ? file.name : 'camera_video.mp4',
    );
  }

  @override
  void initState() {
    super.initState();

    _editorController = QuillController(
      document: Document.fromJson(const [{'insert': '\n'}]),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _editorController.addListener(() {
      final o = _editorController.selection.baseOffset;
      if (o >= 0) _lastValidOffset = o;
    });

    _loadExistingPost();
  }

  Future<void> _loadExistingPost() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('community')
          .doc(widget.docId)
          .get();

      if (!snap.exists) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      _title.text = (data['title'] ?? '').toString();

      final blocks = (data['blocks'] as List?) ?? [];

      // ✅ 일단 "텍스트만" 로딩 (너가 원한 단계)
      final List<Map<String, dynamic>> ops = [];
      for (final raw in blocks) {
        if (raw is! Map) continue;
        final b = Map<String, dynamic>.from(raw);
        if ((b['t'] ?? '').toString() == 'text') {
          final text = (b['v'] ?? '').toString();
          if (text.isNotEmpty) ops.add({'insert': text});
        }
      }

      if (ops.isEmpty) {
        ops.add({'insert': '\n'});
      } else {
        final last = (ops.last['insert'] ?? '').toString();
        if (!last.endsWith('\n')) ops.add({'insert': '\n'});
      }

      final doc = Document.fromJson(ops);

      if (!mounted) return;
      setState(() {
        _editorController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _editorController.addListener(() {
          final o = _editorController.selection.baseOffset;
          if (o >= 0) _lastValidOffset = o;
        });
        _loading = false;
      });
    } catch (e) {
      debugPrint("❌ _loadExistingPost error: $e");
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러: $e')),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 1,
      body: Scaffold(
        appBar: AppBar(title: const Text('수정')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: "제목",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // ✅ 너가 만들었던 에디터 UI (툴바 + 에디터)
              MiniQuillToolbar(
                controller: _editorController,
                onPickImageGallery: _pickFromGalleryAndInsert,
                onPickVideoGallery: _pickVideoFromGalleryAndInsert,
                onPickImageCamera: _pickFromCameraAndInsert,
                onPickVideoCamera: _pickVideoFromCameraAndInsert,
              ),
              const SizedBox(height: 8),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QuillEditor.basic(
                    controller: _editorController,
                    config: QuillEditorConfig(
                      placeholder: '내용을 입력하세요...',
                      embedBuilders: [
                        LocalImageEmbedBuilder(),
                        LocalVideoEmbedBuilder(
                          onPlay: (path, name) => _openVideoPlayerSheet(path: path, title: name),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
