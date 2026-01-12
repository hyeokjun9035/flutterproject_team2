// lib/community/community_editor_widgets.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class MiniQuillToolbar extends StatelessWidget {
  final QuillController controller;

  final VoidCallback onPickImageGallery;
  final VoidCallback onPickVideoGallery;
  final VoidCallback onPickImageCamera;
  final VoidCallback onPickVideoCamera;

  const MiniQuillToolbar({
    super.key,
    required this.controller,
    required this.onPickImageGallery,
    required this.onPickVideoGallery,
    required this.onPickImageCamera,
    required this.onPickVideoCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _icon(icon: Icons.undo, onTap: () { if (controller.hasUndo) controller.undo(); }),
          _icon(icon: Icons.redo, onTap: () { if (controller.hasRedo) controller.redo(); }),

          _toggleAttr(icon: Icons.format_bold, attr: Attribute.bold),
          _toggleAttr(icon: Icons.format_italic, attr: Attribute.italic),
          _toggleAttr(icon: Icons.format_underline, attr: Attribute.underline),
          _toggleList(icon: Icons.format_list_bulleted, listType: Attribute.ul),

          const Spacer(),

          _icon(icon: Icons.photo_outlined, onTap: onPickImageGallery),
          _icon(icon: Icons.videocam_outlined, onTap: onPickVideoGallery),

          PopupMenuButton<String>(
            tooltip: '카메라',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            onSelected: (v) {
              if (v == 'photo') onPickImageCamera();
              if (v == 'video') onPickVideoCamera();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'photo', child: Text('사진 촬영')),
              PopupMenuItem(value: 'video', child: Text('동영상 촬영')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _icon({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 20,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }

  Widget _toggleAttr({required IconData icon, required Attribute attr}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 20,
      onPressed: () {
        final current = controller.getSelectionStyle().attributes[attr.key];
        controller.formatSelection(current == null ? attr : Attribute.clone(attr, null));
      },
      icon: Icon(icon),
    );
  }

  Widget _toggleList({required IconData icon, required Attribute listType}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 20,
      onPressed: () {
        final attrs = controller.getSelectionStyle().attributes;
        final current = attrs[Attribute.list.key];
        controller.formatSelection(current == null ? listType : Attribute.clone(Attribute.list, null));
      },
      icon: Icon(icon),
    );
  }
}

class LocalImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType; // 'image'

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final embed = embedContext.node as Embed;
    final String path = embed.value.data.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('이미지를 불러올 수 없음'),
        ),
      ),
    );
  }
}

class VideoBlockEmbed extends CustomBlockEmbed {
  static const String kType = 'local_video';
  VideoBlockEmbed(String value) : super(kType, value);
}

String? extractLocalVideoRawFromInsertMap(Map insert) {
  const kType = 'local_video';
  if (insert.containsKey(kType)) return insert[kType]?.toString();

  if (insert.containsKey('custom')) {
    final customStr = insert['custom']?.toString();
    if (customStr == null || customStr.isEmpty) return null;
    try {
      final decoded = jsonDecode(customStr);
      if (decoded is Map && decoded.containsKey(kType)) return decoded[kType]?.toString();
    } catch (_) {}
  }
  return null;
}

class LocalVideoEmbedBuilder extends EmbedBuilder {
  final void Function(String path, String name) onPlay;
  LocalVideoEmbedBuilder({required this.onPlay});

  @override
  String get key => VideoBlockEmbed.kType;

  final Map<String, Future<Uint8List?>> _thumbCache = {};

  Future<Uint8List?> _thumbBytes(String path) {
    return _thumbCache.putIfAbsent(path, () async {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 900,
        quality: 75,
      );
      return bytes;
    });
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final embed = embedContext.node as Embed;
    final raw = embed.value.data.toString();

    String path = raw;
    String name = raw.split('/').last;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      path = (m['path'] ?? path).toString();
      name = (m['name'] ?? name).toString();
    } catch (_) {}

    if (path.isEmpty || !File(path).existsSync()) {
      return _fallback(name);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder<Uint8List?>(
          future: _thumbBytes(path),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final bytes = snap.data;
            if (bytes == null) return _fallback(name);

            return GestureDetector(
              onTap: () => onPlay(path, name),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 34),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fallback(String name) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
    ),
    child: Row(
      children: [
        const Icon(Icons.movie_outlined),
        const SizedBox(width: 8),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}
class HybridImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  bool _isUrl(String s) => s.startsWith('http://') || s.startsWith('https://');

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final embed = embedContext.node as Embed;
    final data = embed.value.data.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _isUrl(data)
            ? Image.network(data, fit: BoxFit.cover)
            : Image.file(File(data), fit: BoxFit.cover),
      ),
    );
  }
}

class HybridVideoEmbedBuilder extends EmbedBuilder {
  final void Function(String source, String name) onPlay;
  HybridVideoEmbedBuilder({required this.onPlay});

  @override
  String get key => VideoBlockEmbed.kType;

  bool _isUrl(String s) => s.startsWith('http://') || s.startsWith('https://');

  // ✅ 로컬 비디오 썸네일 캐시(영상 path 기준)
  final Map<String, Future<Uint8List?>> _thumbCache = {};

  Future<Uint8List?> _thumbBytesFromVideo(String videoPath) {
    return _thumbCache.putIfAbsent(videoPath, () async {
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 900,
          quality: 75,
        );
        return bytes;
      } catch (_) {
        return null;
      }
    });
  }

  Widget _fallbackBox() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.black45, size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final embed = embedContext.node as Embed;
    final raw = embed.value.data.toString();

    String source = raw; // url or local path
    String name = raw.split('/').last;
    String thumb = '';

    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        source = (m['url'] ?? m['path'] ?? source).toString();
        name = (m['name'] ?? name).toString();
        thumb = (m['thumb'] ?? '').toString();
      }
    } catch (_) {}

    // ✅ 썸네일 위젯 결정
    Widget thumbWidget;

    // 1) thumb가 "URL"이면 network로
    if (thumb.isNotEmpty && _isUrl(thumb)) {
      thumbWidget = Image.network(thumb, fit: BoxFit.cover);
    }
    // 2) thumb가 "로컬 경로"이고 파일이 있으면 file로
    else if (thumb.isNotEmpty && !_isUrl(thumb) && File(thumb).existsSync()) {
      thumbWidget = Image.file(File(thumb), fit: BoxFit.cover);
    }
    // 3) thumb가 비어있거나 없으면:
    //    - source가 로컬 비디오면 영상에서 썸네일 생성
    else if (!_isUrl(source) && File(source).existsSync()) {
      thumbWidget = FutureBuilder<Uint8List?>(
        future: _thumbBytesFromVideo(source),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final bytes = snap.data;
          if (bytes == null) return _fallbackBox();
          return Image.memory(bytes, fit: BoxFit.cover);
        },
      );
    }
    // 4) 나머지는 fallback
    else {
      thumbWidget = _fallbackBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => onPlay(source, name),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: thumbWidget,
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 34),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
