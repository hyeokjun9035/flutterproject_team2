import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'notices/notice_edit_page.dart';

class AdminPostDetailPage extends StatefulWidget {
  final String docId;

  const AdminPostDetailPage({super.key, required this.docId});

  @override
  State<AdminPostDetailPage> createState() => _AdminPostDetailPageState();
}

class _AdminPostDetailPageState extends State<AdminPostDetailPage> {
  int? _playingVideoIndex;
  VideoPlayerController? _vp;
  ChewieController? _chewie;

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    _chewie?.dispose();
    _chewie = null;
    await _vp?.dispose();
    _vp = null;
    _playingVideoIndex = null;
  }

  Future<void> _playVideoAt(int idx, String url) async {
    if (_playingVideoIndex == idx && _vp != null && _chewie != null) return;
    await _disposePlayer();
    setState(() => _playingVideoIndex = idx);

    final vp = VideoPlayerController.networkUrl(Uri.parse(url));
    _vp = vp;

    try {
      await vp.initialize();
      _chewie = ChewieController(
        videoPlayerController: vp,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
      );
      if (mounted) setState(() {});
    } catch (e) {
      await _disposePlayer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('영상 로드 실패: $e')));
      }
    }
  }

  String _fmtTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  Future<void> _deletePost(BuildContext context, Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 게시글을 삭제하시겠습니까? 관련 이미지와 영상도 함께 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    final images = data['images'] ?? [];
    final videos = data['videos'] ?? [];

    Future<void> deleteUrls(dynamic urls) async {
      if (urls is! List) return;
      for (final u in urls) {
        if (u is String && u.startsWith('http')) {
          try { await FirebaseStorage.instance.refFromURL(u).delete(); } catch (_) {}
        }
      }
    }
    await deleteUrls(images);
    await deleteUrls(videos);
    await FirebaseFirestore.instance.collection('community').doc(widget.docId).delete();

    if (context.mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('community').doc(widget.docId);
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final data = snapshot.data?.data();
        if (data == null) return const Scaffold(body: Center(child: Text('게시글을 찾을 수 없습니다.')));

        final category = (data['category'] ?? '상세보기').toString();
        
        // 작성자 확인 (본인 글인지 확인)
        String? authorUid;
        final author = data['author'];
        if (author is Map) {
          authorUid = author['uid']?.toString();
        } else {
          authorUid = (data['createdBy'] ?? data['user_id'])?.toString();
        }
        final isAuthor = currentUser != null && authorUid == currentUser.uid;
        
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              // ✅ 본인이 작성한 글(주로 공지사항)일 때만 수정 버튼 노출
              if (isAuthor)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoticeEditPage(docId: widget.docId, initial: data))),
                ),
              // 삭제 버튼은 관리자 권한이므로 항상 노출 (지우면 지웠지 수정은 안 함 정책 반영)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deletePost(context, data),
              ),
            ],
          ),
          body: _buildBody(data),
        );
      },
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString();
    final blocks = (data['blocks'] as List?)?.cast<dynamic>() ?? [];
    final images = (data['images'] as List?)?.cast<String>() ?? [];
    final videos = (data['videos'] as List?)?.cast<String>() ?? [];
    final videoThumbs = (data['videoThumbs'] as List?)?.cast<String>() ?? [];

    final authorMap = (data['author'] as Map<String, dynamic>?) ?? {};
    final authorName = (authorMap['nickName'] ?? authorMap['name'] ?? '익명').toString();
    final authorProfile = (authorMap['profile_image_url'] ?? '').toString();
    final createdAt = data['createdAt'];
    final reportCount = data['report_count'] ?? 0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (reportCount > 0)
          Container(
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.report_problem, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Text('신고 횟수: $reportCount회', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black12,
                backgroundImage: authorProfile.isNotEmpty ? NetworkImage(authorProfile) : null,
                child: authorProfile.isEmpty ? const Icon(Icons.person, size: 16, color: Colors.black54) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(_fmtTime(createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.35)),
          ),

        if (blocks.isNotEmpty)
          ..._buildContentBlocks(blocks, images, videos, videoThumbs)
        else ...[
          if (images.isNotEmpty)
            ...images.map((url) => _imageWidget(url)),
          if (videos.isNotEmpty)
            ...videos.asMap().entries.map((e) => _videoItemWidget(e.key, e.value, videoThumbs)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(data['plain'] ?? data['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ],
        
        const Divider(height: 1, thickness: 1),

        // 댓글 섹션 추가
        _buildCommentSection(),
        
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("댓글", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('community')
                .doc(widget.docId)
                .collection('comments')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("등록된 댓글이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snap.data!.docs.length,
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final comment = snap.data!.docs[index].data();
                  final cAuthor = comment['author'] ?? {};
                  final cNick = (cAuthor['nickName'] ?? cAuthor['name'] ?? '익명').toString();
                  final cContent = (comment['content'] ?? '').toString();
                  final cTime = comment['createdAt'];

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(radius: 12, backgroundColor: Colors.black12, child: Icon(Icons.person, size: 14, color: Colors.black54)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(cNick, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Text(_fmtTime(cTime), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                const Spacer(),
                                // 관리자용 댓글 삭제 기능 (필요시)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                                  onPressed: () => _deleteComment(snap.data!.docs[index].id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(cContent, style: const TextStyle(fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('community')
          .doc(widget.docId)
          .collection('comments')
          .doc(commentId)
          .delete();
    }
  }

  List<Widget> _buildContentBlocks(List<dynamic> blocks, List<String> images, List<String> videos, List<String> videoThumbs) {
    final widgets = <Widget>[];
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final b = Map<String, dynamic>.from(raw);
      final t = (b['t'] ?? '').toString();

      if (t == 'text') {
        final v = (b['v'] ?? '').toString();
        if (v.trim().isEmpty) continue;
        widgets.add(Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text(v, style: const TextStyle(fontSize: 14, height: 1.45))));
      } else if (t == 'image') {
        final idx = (b['v'] as num?)?.toInt() ?? -1;
        if (idx >= 0 && idx < images.length) widgets.add(_imageWidget(images[idx]));
      } else if (t == 'video') {
        final idx = (b['v'] as num?)?.toInt() ?? -1;
        if (idx >= 0 && idx < videos.length) widgets.add(_videoItemWidget(idx, videos[idx], videoThumbs));
      }
    }
    return widgets;
  }

  Widget _imageWidget(String url) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(aspectRatio: 16 / 9, child: Image.network(url, fit: BoxFit.cover)),
      ),
    );
  }

  Widget _videoItemWidget(int idx, String videoUrl, List<String> videoThumbs) {
    final thumb = (idx < videoThumbs.length) ? videoThumbs[idx] : '';
    final isPlaying = _playingVideoIndex == idx && _chewie != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: isPlaying
              ? Stack(
                  children: [
                    Chewie(controller: _chewie!),
                    Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _disposePlayer)),
                  ],
                )
              : InkWell(
                  onTap: () => _playVideoAt(idx, videoUrl),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (thumb.isNotEmpty) Image.network(thumb, fit: BoxFit.cover, width: double.infinity, height: double.infinity) else Container(color: Colors.black12),
                      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: Colors.white, size: 30)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
