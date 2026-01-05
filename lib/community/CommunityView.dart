import 'package:flutter/material.dart';
import '../headandputter/putter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'CommunityEdit.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Communityview extends StatefulWidget {
  final String docId;

  const Communityview({super.key, required this.docId});

  @override
  State<Communityview> createState() => _CommunityviewState();
}

class _CommunityviewState extends State<Communityview> {
  String _timeAgoFromTs(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "방금 전";
    if (diff.inMinutes < 60) return "${diff.inMinutes}분 전";
    if (diff.inHours < 24) return "${diff.inHours}시간 전";
    if (diff.inDays < 7) return "${diff.inDays}일 전";

    return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}";
  }

  DateTime? _readFirestoreTime(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  int? _playingVideoIndex;
  VideoPlayerController? _vp;
  ChewieController? _chewie;

  Future<void> _reportPost({
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reasons = ['스팸/광고', '욕설/비방', '음란물', '개인정보 노출', '기타'];
    String selected = reasons.first;
    final detailCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('신고하기'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selected,
                isExpanded: true,
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => selected = v!),
              ),
              if (selected == '기타')
                TextField(
                  controller: detailCtrl,
                  decoration: const InputDecoration(hintText: '사유를 입력하세요'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('신고')),
        ],
      ),
    );

    if (ok != true) return;

    final postId = doc.id;
    final reporterUid = user.uid;
    final reportId = '${postId}_$reporterUid';

    final category = (data['category'] ?? '').toString();
    final authorMap = (data['author'] as Map<String, dynamic>?) ?? {};
    final postAuthorUid = (data['createdBy'] ?? authorMap['uid'] ?? '').toString();

    final title = (data['title'] ?? '').toString();
    final plain = (data['plain'] ?? data['content'] ?? '').toString();

    try{
      await FirebaseFirestore.instance.collection('reports').doc(reportId).set({
        'postId': postId,
        'postRef': FirebaseFirestore.instance.collection('community').doc(postId),
        'category': category,

        'postAuthorUid': postAuthorUid,
        'postTitle': title,
        'postPlain': plain,

        'reportedByUid': reporterUid,
        'reportedByEmail': user.email ?? '',

        'reason': selected,
        'detail': selected == '기타' ? detailCtrl.text.trim() : '',

        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고가 접수되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신고 저장 실패: $e')),
      );
    }
  }

  Future<void> _playVideoAt(int idx, String url) async {
    if (_playingVideoIndex == idx && _vp != null && _chewie != null) return;

    await _disposePlayer();

    setState(() => _playingVideoIndex = idx);

    final vp = VideoPlayerController.networkUrl(Uri.parse(url));
    _vp = vp;

    try {
      await vp.initialize();
    } catch (e) {
      await _disposePlayer();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('영상 로드 실패: $e')));
      return;
    }

    _chewie = ChewieController(
      videoPlayerController: vp,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowPlaybackSpeedChanging: true,
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _disposePlayer() async {
    _chewie?.dispose();
    _chewie = null;
    await _vp?.dispose();
    _vp = null;
    _playingVideoIndex = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 1,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community')
            .doc(widget.docId)
            .snapshots(),
        builder: (context, snap) {
          String appBarTitle = "로딩중";

          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data() as Map<String, dynamic>;
            appBarTitle = (data['category'] ?? '상세보기').toString();
          }

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                appBarTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            body: _buildBody(snap),
          );
        },
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<DocumentSnapshot> snap) {
    if (snap.hasError) return Center(child: Text('에러: ${snap.error}'));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    if (!snap.data!.exists) return const Center(child: Text('삭제된 글입니다.'));

    final doc = snap.data!;
    final data = doc.data() as Map<String, dynamic>;
    final title = (data['title'] ?? '').toString();
    final blocks = (data['blocks'] as List?)?.cast<dynamic>() ?? [];
    final images = (data['images'] as List?)?.cast<String>() ?? [];
    final videos = (data['videos'] as List?)?.cast<String>() ?? [];
    final videoThumbs = (data['videoThumbs'] as List?)?.cast<String>() ?? [];

    final authorMap = (data['author'] as Map<String, dynamic>?) ?? {};
    final authorName = (authorMap['nickName'] ?? authorMap['name'] ?? '익명')
        .toString();
    final authorProfile = (authorMap['profile_image_url'] ?? '').toString();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final authorUid = (authorMap['uid'] ?? '').toString();
    final bool isMine = currentUid != null && currentUid == authorUid;

    final createdAt =
        _readFirestoreTime(data, "createdAt") ??
        _readFirestoreTime(data, "createdAtClient");

    final updatedAt =
        _readFirestoreTime(data, "updatedAt") ??
        _readFirestoreTime(data, "updatedAtClient");

    final displayDt = updatedAt ?? createdAt;
    final bool edited =
        (createdAt != null &&
        updatedAt != null &&
        updatedAt.isAfter(createdAt));
    final timeLabel = displayDt == null ? "" : _timeAgoFromTs(displayDt);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 작성자 영역
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black12,
                backgroundImage: authorProfile.isNotEmpty
                    ? NetworkImage(authorProfile)
                    : null,
                child: authorProfile.isEmpty
                    ? const Icon(Icons.person, size: 16, color: Colors.black54)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (timeLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          edited ? "$timeLabel · 수정됨" : timeLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                padding: EdgeInsets.zero,
                onSelected: (value) async {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CommunityEdit(docId: doc.id), // ✅ docId 유지
                      ),
                    );
                  } else if (value == 'delete') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("삭제"),
                        content: const Text("정말 삭제하시겠습니까?"),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection("community")
                                  .doc(doc.id)
                                  .delete();

                              if (context.mounted)
                                Navigator.of(context).pop(); // 다이얼로그 닫기
                              if (mounted)
                                Navigator.of(this.context).pop(); // 상세 화면 닫기
                            },
                            child: const Text("삭제"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("취소"),
                          ),
                        ],
                      ),
                    );
                  } else if (value == 'report') {
                    await _reportPost(doc: doc, data: data);
                  }
                },

                itemBuilder: (_) {
                  if (isMine) {
                    return const [
                      PopupMenuItem(value: 'edit', child: Text('수정')),
                      PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ];
                  } else {
                    return const [
                      PopupMenuItem(value: 'report', child: Text('신고')),
                    ];
                  }
                },
              ),
            ],
          ),
        ),

        // 제목
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.35,
              ),
            ),
          ),

        // 본문 렌더링
        if (blocks.isNotEmpty)
          ..._buildContentBlocks(
            images: images,
            videos: videos,
            videoThumbs: videoThumbs,
            blocks: blocks,
          )
        else ...[
          // ✅ 블록이 없는 경우 (공지사항 등) 폴백 처리 추가
          if (images.isNotEmpty) ...images.map((url) => _imageWidget(url)),
          if (videos.isNotEmpty)
            ...videos.asMap().entries.map(
              (e) => _videoItemWidget(e.key, e.value, videoThumbs),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(
              data['plain'] ?? data['content'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.55),
            ),
          ),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1),
        ),

        // 댓글 섹션
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "댓글",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _commentInput(),
              const SizedBox(height: 12),
              const Text(
                "댓글 기능 연결 예정",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildContentBlocks({
    required List<dynamic> blocks,
    required List<String> images,
    required List<String> videos,
    required List<String> videoThumbs,
  }) {
    final widgets = <Widget>[];
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final b = Map<String, dynamic>.from(raw);
      final t = (b['t'] ?? '').toString();

      if (t == 'text') {
        final v = (b['v'] ?? '').toString();
        if (v.trim().isEmpty) continue;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(v, style: const TextStyle(fontSize: 14, height: 1.45)),
          ),
        );
      } else if (t == 'image') {
        final idx = (b['v'] as num?)?.toInt() ?? -1;
        if (idx >= 0 && idx < images.length)
          widgets.add(_imageWidget(images[idx]));
      } else if (t == 'video') {
        final idx = (b['v'] as num?)?.toInt() ?? -1;
        if (idx >= 0 && idx < videos.length)
          widgets.add(_videoItemWidget(idx, videos[idx], videoThumbs));
      }
    }
    return widgets;
  }

  Widget _imageWidget(String url) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(url, fit: BoxFit.cover),
        ),
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
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _disposePlayer,
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: () => _playVideoAt(idx, videoUrl),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (thumb.isNotEmpty)
                        Image.network(thumb, fit: BoxFit.cover)
                      else
                        Container(color: Colors.black12),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _commentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "댓글을 입력하세요...",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.send, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
