import 'package:flutter/material.dart';
import 'package:flutter_project/headandputter/putter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'CommunityEdit.dart';

class Communityview extends StatefulWidget {
  final String docId;

  const Communityview({super.key, required this.docId});

  @override
  State<Communityview> createState() => _CommunityviewState();
}

class _CommunityviewState extends State<Communityview> {
  int? _playingVideoIndex;
  VideoPlayerController? _vp;
  ChewieController? _chewie;

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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: Colors.black12,
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
    if (snap.hasError) {
      return Center(child: Text('에러: ${snap.error}'));
    }

    if (!snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!snap.data!.exists) {
      return const Center(child: Text('삭제된 글입니다.'));
    }

    final data = snap.data!.data() as Map<String, dynamic>;

    final title = (data['title'] ?? '').toString();
    final blocks = (data['blocks'] as List?)?.cast<dynamic>() ?? [];
    final images = (data['images'] as List?)?.cast<String>() ?? [];
    final videos = (data['videos'] as List?)?.cast<String>() ?? [];
    final videoThumbs = (data['videoThumbs'] as List?)?.cast<String>() ?? [];

    final authorMap = (data['author'] as Map<String, dynamic>?) ?? {};
    final authorName = (authorMap['nickName'] ?? authorMap['name'] ?? '익명')
        .toString();
    final authorProfile = (authorMap['profile_image_url'] ?? '').toString();

    final placeMap = (data["place"] as Map<String, dynamic>?) ?? {};
    final placeName = (placeMap["name"] ?? "").toString().trim();
    final placeAddress = (placeMap["address"] ?? "").toString().trim();

    final weatherMap = (data["weather"] as Map<String, dynamic>?) ?? {};
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
    final locationLabel = placeName.isNotEmpty ? placeName : regionLabel;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 5, 0, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 25,
                        height: 1,
                        fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CommunityEdit()),
                      );
                    } else if (value == 'delete') {
                      showDialog(
                        context: context,
                        builder: (_) {
                          return AlertDialog(
                            title: const Text("삭제?"),
                            content: const Text("정말 삭제하시겠습니까?"),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  // TODO: 삭제 처리 넣기

                                },
                                child: const Text("삭제"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("취소"),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              ],
            ),
          ),

          // 작성자 영역
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 0, 5),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // 위로 붙게
                  children: [
                    CircleAvatar(
                      radius: 17,
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
                    const SizedBox(width: 5),
                    // ✅ 닉네임 + 위치를 Column으로 묶기
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),

                          if (locationLabel.isNotEmpty || weatherLabel.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(), // 여기 0~2로 조절
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (locationLabel.isNotEmpty) ...[
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 15,
                                    ),
                                    Flexible(
                                      child: Text(
                                        locationLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                  if (locationLabel.isNotEmpty &&
                                      weatherLabel.isNotEmpty)
                                    const SizedBox(width: 5),
                                  if (weatherLabel.isNotEmpty) ...[
                                    const Icon(Icons.thermostat, size: 15),
                                    Text(
                                      weatherLabel,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ✅ 오른쪽 메뉴는 그대로

                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 3),
            child: Divider(height: 0),
          ),
          // 본문
          ..._buildContentBlocks(
            images: images,
            videos: videos,
            videoThumbs: videoThumbs,
            blocks: blocks,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),

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
      ),
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

      // ✅ text
      if (t == 'text') {
        final v = (b['v'] ?? '').toString();
        if (v.trim().isEmpty) continue;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 5, 0, 5),
            child: Text(v, style: const TextStyle(fontSize: 15, height: 1.45)),
          ),
        );
        continue;
      }

      // ✅ image (v = images index)
      if (t == 'image') {
        final idx = (b['v'] as num?)?.toInt() ?? -1;
        if (idx < 0 || idx >= images.length) continue;

        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(images[idx], fit: BoxFit.cover),
              ),
            ),
          ),
        );
        continue;
      }

      // ✅ video (v = videos index)
      if (t == 'video') {
        final idx = (b['v'] as num?)?.toInt() ?? -1;
        if (idx < 0 || idx >= videos.length) continue;

        final videoUrl = videos[idx];
        final thumb = (idx < videoThumbs.length) ? videoThumbs[idx] : '';
        final isPlaying = _playingVideoIndex == idx && _chewie != null;

        widgets.add(
          Padding(
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
                            child: Material(
                              color: Colors.black.withOpacity(0.35),
                              shape: const CircleBorder(),
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
          ),
        );
        continue;
      }
    }
    return widgets;
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
