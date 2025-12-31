import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

class AdminPostDetailPage extends StatefulWidget {
  final String docId;

  const AdminPostDetailPage({super.key, required this.docId});

  @override
  State<AdminPostDetailPage> createState() => _AdminPostDetailPageState();
}

class _AdminPostDetailPageState extends State<AdminPostDetailPage> {
  // final List<VideoPlayerController> _videoCtrls = [];
  final Map<String, VideoPlayerController> _ctrlByUrl = {};
  final Map<String, Future<void>> _initByUrl = {};

  @override
  void dispose() {
    for (final c in _ctrlByUrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<VideoPlayerController> _getVideoCtrl(String url) async {
    if (_ctrlByUrl.containsKey(url)) return _ctrlByUrl[url]!;

    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _ctrlByUrl[url] = ctrl;

    _initByUrl[url] ??= ctrl.initialize().then((_) {
      ctrl.setLooping(true);
    });

    await _initByUrl[url];
    return ctrl;
  }

  String _fmtTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  Future<void> _deletePost(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 게시글을 삭제할까요? (복구 불가!)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // 🔥 이미지/영상 URL 둘 다 삭제 시도
    final images = data['images'] ?? data['image_urls'];
    final videos = data['videos'];

    Future<void> _deleteUrls(dynamic urls) async {
      if (urls is! List) return;
      for (final u in urls) {
        if (u is String && u.startsWith('http')) {
          try {
            await FirebaseStorage.instance.refFromURL(u).delete();
          } catch (_) {}
        }
      }
    }

    await _deleteUrls(images);
    await _deleteUrls(videos);

    await FirebaseFirestore.instance
        .collection('community')
        .doc(widget.docId)
        .delete();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제 완료')));
      Navigator.pop(context, true);
    }
  }

  // ✅ URL로 video 컨트롤러 만들어서 재사용
  // Future<VideoPlayerController> _createVideoCtrl(String url) async {
  //   final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
  //   await ctrl.initialize();
  //   ctrl.setLooping(true);
  //   _videoCtrls.add(ctrl);
  //   return ctrl;
  // }

  // ✅ videos + blocks(video)에서 url 뽑기
  List<String> _extractVideoUrls(Map<String, dynamic> data) {
    final List<String> urls = [];

    final rawVideos = data['videos'];
    final List<String> videos = (rawVideos is List)
        ? rawVideos.whereType<String>().toList()
        : [];

    // 1) videos 배열 URL 그대로
    urls.addAll(videos);

    // 2) blocks에서 video 타입이면 v(index)로 videos[index] 매칭
    final rawBlocks = data['blocks'];
    if (rawBlocks is List) {
      for (final b in rawBlocks) {
        if (b is Map) {
          final t = b['t'];
          if (t == 'video') {
            final idx = b['v'];
            if (idx is int && idx >= 0 && idx < videos.length) {
              final u = videos[idx];
              if (!urls.contains(u)) urls.add(u);
            }
          }
        }
      }
    }

    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('community')
        .doc(widget.docId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글 상세'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final snap = await docRef.get();
              final data = snap.data();
              if (data == null) return;
              if (!context.mounted) return;
              await _deletePost(context, data);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError)
            return const Center(child: Text('에러가 발생했습니다.'));
          final data = snapshot.data?.data();
          if (data == null) return const Center(child: Text('게시글이 존재하지 않습니다.'));

          final title = (data['title'] ?? '(제목 없음)').toString();
          final content = (data['plain'] ?? data['content'] ?? '').toString();
          final category = (data['category'] ?? data['board_type'] ?? '미분류')
              .toString();

          String nickName = 'unknown';
          final author = data['author'];
          if (author is Map) {
            nickName = (author['nickName'] ?? author['name'] ?? 'unknown')
                .toString();
          } else {
            nickName = (data['nickName'] ?? 'unknown').toString();
          }

          final createdAt = data['createdAt'] ?? data['cdate'];
          final reportCount = (data['report_count'] ?? 0);

          final imageUrlsRaw = data['images'] ?? data['image_urls'];
          final List<String> imageUrls = (imageUrlsRaw is List)
              ? imageUrlsRaw.whereType<String>().toList()
              : <String>[];

          // ✅ 동영상 URL 추출
          final videoUrls = _extractVideoUrls(data);

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(category),
                  _chip('작성자: $nickName'),
                  _chip('작성: ${_fmtTime(createdAt)}'),
                  _chip('신고: $reportCount'),
                ],
              ),

              const SizedBox(height: 16),

              // ✅ 이미지 (여러 장이면 전부 세로로 표시)
              if (imageUrls.isNotEmpty) ...[
                ...imageUrls.map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, p) => p == null
                            ? child
                            : const SizedBox(
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 220,
                          child: Center(child: Text('이미지를 불러오지 못했습니다.')),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // ✅ 동영상
              if (videoUrls.isNotEmpty) ...[
                const Text(
                  '동영상',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...videoUrls.map((url) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: FutureBuilder<VideoPlayerController>(
                        future: _getVideoCtrl(url),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return Container(
                              height: 220,
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            );
                          }

                          final ctrl = snap.data!;
                          if (!ctrl.value.isInitialized) {
                            return Container(
                              height: 220,
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            );
                          }

                          return Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              AspectRatio(
                                aspectRatio: ctrl.value.aspectRatio,
                                child: VideoPlayer(ctrl),
                              ),
                              VideoProgressIndicator(
                                ctrl,
                                allowScrubbing: true,
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: IconButton(
                                  icon: Icon(
                                    ctrl.value.isPlaying
                                        ? Icons.pause_circle
                                        : Icons.play_circle,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                  onPressed: () async {
                                    if (ctrl.value.isPlaying) {
                                      await ctrl.pause();
                                    } else {
                                      await ctrl.play();
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                  ;
                }),
                const SizedBox(height: 6),
              ],

              // ✅ 본문
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  content.isEmpty ? '(내용 없음)' : content,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
