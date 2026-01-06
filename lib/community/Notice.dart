import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/community/CommunityView.dart'
    hide Communityview;
import 'CommunityAdd.dart';
import '../headandputter/putter.dart';
import 'CommunityEdit.dart';
import 'CommunityView.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class Notice extends StatefulWidget {
  const Notice({super.key});

  // ✅ 일단 하드코딩 데이터
  static const List<Map<String, dynamic>> posts = [];

  @override
  State<Notice> createState() => _NoticeState();
}

class _NoticeState extends State<Notice> {
  String _timeAgoFromTs(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "방금 전";
    if (diff.inMinutes < 60) return "${diff.inMinutes}분 전";
    if (diff.inHours < 24) return "${diff.inHours}시간 전";
    if (diff.inDays < 7) return "${diff.inDays}일 전";

    // 일주일 넘으면 날짜로
    return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}";
  }

  DateTime? _readFirestoreTime(Map<String, dynamic> data, String key) {
    final v = data[key];

    // serverTimestamp -> Timestamp
    if (v is Timestamp) return v.toDate();

    // client epoch (millis)
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 1,
      body: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          backgroundColor: Colors.grey[200],
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "공지사항",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Communityadd()),
                );
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("community")
              .where("category", isEqualTo: "공지사항")
              .orderBy("createdAt", descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final title = (data["title"] ?? "").toString();
                  final images = ((data["images"] as List?) ?? [])
                      .map((e) => e.toString())
                      .toList();
                  final videos = ((data["videos"] as List?) ?? [])
                      .map((e) => e.toString())
                      .toList();
                  final videoThumbs = ((data["videoThumbs"] as List?) ?? [])
                      .map((e) => e.toString())
                      .toList();

                  // ✅ 사진/영상 섞어서 캐러셀용 아이템 만들기
                  final mediaItems = <Map<String, String>>[];

                  final blocks = (data["blocks"] as List?) ?? [];
                  if (blocks.isNotEmpty) {
                    for (final raw in blocks) {
                      if (raw is! Map) continue;
                      final b = Map<String, dynamic>.from(raw);
                      final t = (b['t'] ?? '').toString();

                      if (t == 'image') {
                        final idx = (b['v'] as num?)?.toInt() ?? -1;
                        if (idx >= 0 && idx < images.length) {
                          mediaItems.add({'type': 'image', 'url': images[idx]});
                        }
                      } else if (t == 'video') {
                        final idx = (b['v'] as num?)?.toInt() ?? -1;
                        if (idx >= 0 && idx < videos.length) {
                          final thumb = (idx < videoThumbs.length)
                              ? videoThumbs[idx]
                              : '';
                          mediaItems.add({
                            'type': 'video',
                            'url': videos[idx],
                            'thumb': thumb,
                          });
                        }
                      }
                    }
                  } else {
                    for (final u in images) {
                      mediaItems.add({'type': 'image', 'url': u});
                    }
                    for (int i = 0; i < videos.length; i++) {
                      mediaItems.add({
                        'type': 'video',
                        'url': videos[i],
                        'thumb': (i < videoThumbs.length) ? videoThumbs[i] : '',
                      });
                    }
                  }

                  // author는 Map으로 저장했으니 문자열로 바로 못 씀
                  final authorMap =
                      (data["author"] as Map<String, dynamic>?) ?? {};
                  final authorName =
                  (authorMap["nickName"] ?? authorMap["name"] ?? "익명")
                      .toString();
                  final authorProfile = (authorMap['profile_image_url'] ?? '')
                      .toString();

                  final currentUid = FirebaseAuth.instance.currentUser?.uid;
                  final authorUid = (authorMap["uid"] ?? "").toString();
                  final bool isMine =
                      currentUid != null && currentUid == authorUid;

                  final placeMap =
                      (data["place"] as Map<String, dynamic>?) ?? {};
                  final placeName = (placeMap["name"] ?? "").toString().trim();
                  final placeAddress = (placeMap["address"] ?? "")
                      .toString()
                      .trim();

                  final weatherMap =
                      (data["weather"] as Map<String, dynamic>?) ?? {};
                  final temp =
                  weatherMap["temp"]; // _addCommunity에서 'weather': {'temp': _temp ...}

                  String weatherLabel = "";
                  if (temp != null) {
                    // temp가 int/double 섞일 수 있어서 num 처리
                    final num t = (temp as num);
                    weatherLabel = "온도 ${t.toStringAsFixed(0)}°";
                  }

                  // 지역명(시/도 + 구/시/군) 간단 파싱
                  String regionLabel = "";
                  if (placeAddress.isNotEmpty) {
                    final parts = placeAddress.split(' ');
                    if (parts.length >= 2) {
                      regionLabel = "${parts[0]} ${parts[1]}"; // 예: "서울특별시 강남구"
                    } else {
                      regionLabel = parts[0];
                    }
                  }

                  // 화면에 보여줄 최종 라벨: placeName 우선, 없으면 regionLabel
                  final locationLabel = placeName.isNotEmpty
                      ? placeName
                      : regionLabel;

                  final bool hasMetaInfo =
                      locationLabel.isNotEmpty || weatherLabel.isNotEmpty;

                  final createdAt =
                      _readFirestoreTime(data, "createdAt") ??
                          _readFirestoreTime(data, "createdAtClient");
                  final updatedAt =
                      _readFirestoreTime(data, "updatedAt") ??
                          _readFirestoreTime(data, "updatedAtClient");

                  // 표시 기준: updatedAt 있으면 updatedAt, 없으면 createdAt
                  final displayDt = updatedAt ?? createdAt;

                  // 수정 여부 판단(둘 다 있을 때만 확실)
                  final bool edited =
                  (createdAt != null &&
                      updatedAt != null &&
                      updatedAt.isAfter(createdAt));

                  final timeLabel = displayDt == null
                      ? ""
                      : _timeAgoFromTs(displayDt);

                  final views = (data["viewCount"] ?? 0);
                  final comments = (data["commentCount"] ?? 0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // 위로 붙게
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black12,
                              backgroundImage: authorProfile.isNotEmpty
                                  ? NetworkImage(authorProfile)
                                  : null,
                              child: authorProfile.isEmpty
                                  ? const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.black54,
                              )
                                  : null,
                            ),
                            const SizedBox(width: 8),

                            // ✅ 닉네임 + 위치를 Column으로 묶기
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: hasMetaInfo
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.center,
                                children: [
                                  Text(
                                    authorName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  if (hasMetaInfo)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (locationLabel.isNotEmpty) ...[
                                            const Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                            ),
                                            Flexible(
                                              child: Text(
                                                locationLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],

                                          if (locationLabel.isNotEmpty &&
                                              weatherLabel.isNotEmpty)
                                            const SizedBox(width: 6),

                                          if (weatherLabel.isNotEmpty) ...[
                                            const Icon(
                                              Icons.thermostat,
                                              size: 16,
                                            ),
                                            Text(
                                              weatherLabel,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // ✅ 오른쪽 메뉴는 그대로
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              padding: EdgeInsets.zero,
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommunityEdit(
                                        docId: doc.id,
                                      ), // ✅ docId 유지
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
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text("삭제"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text("취소"),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (value == 'report') {
                                  // 🚧 하드코딩: 아직 기능 없음
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('신고 기능은 준비중입니다.'),
                                    ),
                                  );
                                }
                              },

                              itemBuilder: (_) {
                                if (isMine) {
                                  return const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('수정'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('삭제'),
                                    ),
                                  ];
                                } else {
                                  return const [
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Text('신고'),
                                    ),
                                  ];
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Communityview(docId: doc.id),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),

                        if (mediaItems.isNotEmpty) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Communityview(docId: doc.id),
                                ),
                              );
                            },
                            child: _MediaCarousel(items: mediaItems),
                          ),
                        ],

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            // createdAt을 time(“3분전”)으로 만들려면 따로 변환 로직 필요
                            Text(
                              edited ? "$timeLabel · 수정됨" : timeLabel,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$views",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.comment_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$comments",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MediaCarousel extends StatefulWidget {
  final List<Map<String, String>> items;
  const _MediaCarousel({required this.items});

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  final _pc = PageController();
  int _index = 0;

  int? _playingIndex;
  VideoPlayerController? _vp;
  ChewieController? _chewie;

  Future<void> _playVideoAt(int idx, String url) async {
    if (_playingIndex == idx && _vp != null && _chewie != null) return;

    await _disposePlayer();
    setState(() => _playingIndex = idx);

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
    _playingIndex = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pc,
              itemCount: total,
              onPageChanged: (i) async {
                setState(() => _index = i);
                // ✅ 페이지 넘기면 재생 중이면 꺼버리기 (인스타 느낌)
                if (_playingIndex != null && _playingIndex != i) {
                  await _disposePlayer();
                  if (mounted) setState(() {});
                }
              },
              itemBuilder: (_, i) {
                final it = widget.items[i];
                final type = (it['type'] ?? 'image').trim();

                if (type == 'video') {
                  final thumb = (it['thumb'] ?? '').trim();
                  final videoUrl = (it['url'] ?? '').trim();

                  final isPlaying = _playingIndex == i && _chewie != null;

                  return isPlaying
                      ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Chewie(controller: _chewie!),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            await _disposePlayer();
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    ],
                  )
                      : InkWell(
                    onTap: () {
                      if (videoUrl.isNotEmpty) _playVideoAt(i, videoUrl);
                    },
                    child: Stack(
                      fit: StackFit.expand,
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
                  );
                }

                final url = (it['url'] ?? '').trim();
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Text("이미지 없음"),
                  ),
                );
              },
            ),
          ),

          // 오른쪽 상단 1/8 표시
          if (total > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  "${_index + 1}/$total",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // 아래 점 인디케이터
          if (total > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 10 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
