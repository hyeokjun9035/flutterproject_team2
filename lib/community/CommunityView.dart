import 'package:flutter/material.dart';
import '../headandputter/putter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'CommunityEdit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

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

  bool _viewCounted = false; // ✅ 추가

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _increaseViewCountOnce());
  }

  Future<void> _increaseViewCountOnce() async {
    if (_viewCounted) return;
    _viewCounted = true;

    try {
      final ref = FirebaseFirestore.instance.collection('community').doc(widget.docId);
      await ref.update({'viewCount': FieldValue.increment(1)});
    } catch (e) {
      // 실패해도 화면은 계속 보이게
      debugPrint('viewCount update failed: $e');
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postSnap = await FirebaseFirestore.instance
        .collection('community')
        .doc(widget.docId)
        .get();

    final postData = postSnap.data() ?? {};
    final authorDeleted = postData['authorDeleted'] == true;

    if (authorDeleted) return;

    final postRef = FirebaseFirestore.instance.collection('community').doc(widget.docId);
    final likeRef = postRef.collection('likes').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);

      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  Widget _placeMapWidget(Map<String, dynamic>? place, String weatherLabel) {
    if (place == null) return const SizedBox.shrink();

    final lat = (place['lat'] as num?)?.toDouble();
    final lng = (place['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return const SizedBox.shrink();

    final name = (place['name'] ?? '위치').toString();
    final address = (place['address'] ?? '').toString();
    final pos = LatLng(lat, lng);

    LatLngBounds _boundsFromCenter(LatLng c, double radiusMeters) {
      // 위도 1도 ≈ 111km
      final latDelta = radiusMeters / 111000.0;
      // 경도는 위도에 따라 달라짐
      final lngDelta = radiusMeters / (111000.0 * (cos(c.latitude * pi / 180)));

      return LatLngBounds(
        southwest: LatLng(c.latitude - latDelta, c.longitude - lngDelta),
        northeast: LatLng(c.latitude + latDelta, c.longitude + lngDelta),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 텍스트
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (address.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                address,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (weatherLabel.trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.thermostat, size: 18, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        weatherLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),

              // 지도 (핀만)
              SizedBox(
                height: 220,
                width: double.infinity,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: pos, zoom: 17), // 임시값
                  onMapCreated: (c) async {
                    // ✅ 여기 숫자만 조절하면 "처음부터 얼마나 가까이"가 결정됨
                    // 200~400m 정도가 사고 위치 표시엔 보통 좋음
                    final bounds = _boundsFromCenter(pos, 100); // 반경 250m

                    // bounds 적용 (약간의 padding)
                    await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 24));
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('place'),
                      position: pos,
                      infoWindow: InfoWindow(title: name),
                    ),
                  },
                  liteModeEnabled: true,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _likeButton(String postId, int likeCount, {required bool authorDeleted}) {
    final user = FirebaseAuth.instance.currentUser;

    // ✅ (A) 로그인 안했거나, 탈퇴글이면: 아이콘은 보여주되 비활성 + 카운트 표시
    if (user == null || authorDeleted) {
      return InkWell(
        onTap: authorDeleted
            ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('탈퇴한 사용자의 글에는 좋아요를 누를 수 없습니다.')),
          );
        }
            : null, // 로그인 유도하고 싶으면 여기에 스낵바 추가 가능
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 18, color: Colors.black26),
            const SizedBox(width: 4),
            Text(
              '$likeCount',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    // ✅ (B) 정상글 + 로그인 상태면: 기존처럼 실시간 liked 반영
    final likeDocStream = FirebaseFirestore.instance
        .collection('community')
        .doc(postId)
        .collection('likes')
        .doc(user.uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: likeDocStream,
      builder: (context, snap) {
        final liked = snap.data?.exists ?? false;

        return InkWell(
          onTap: _toggleLike, // _toggleLike 안에서 authorDeleted 방어 이미 해둠(굿)
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: liked ? Colors.red : Colors.black54,
              ),
              const SizedBox(width: 4),
              Text('$likeCount', style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
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

  final TextEditingController _commentCtrl = TextEditingController();
  bool _sendingComment = false;

  Future<void> _addComment({
    required DocumentSnapshot postDoc,
    required Map<String, dynamic> postData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (postData['authorDeleted'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('탈퇴한 사용자의 글에는 댓글을 작성할 수 없습니다.')),
      );
      return;
    }

    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sendingComment = true);

    try {
      final fs = FirebaseFirestore.instance;

      // 작성자 정보: postData의 author 말고 users에서 가져오는 게 정확함(닉 변경 등)
      final userSnap = await fs.collection('users').doc(user.uid).get();
      final u = userSnap.data() ?? {};

      final author = {
        'uid': user.uid,
        'nickName': (u['nickName'] ?? u['nickname'] ?? '익명').toString(),
        'profile_image_url': (u['profile_image_url'] ?? '').toString(),
      };

      final postRef = fs.collection('community').doc(postDoc.id);
      final commentRef = postRef.collection('comments').doc();

      await fs.runTransaction((tx) async {
        tx.set(commentRef, {
          'text': text,
          'author': author,
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtClient': DateTime.now().millisecondsSinceEpoch,
        });

        // commentCount +1
        tx.update(postRef, {
          'commentCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtClient': DateTime.now().millisecondsSinceEpoch,
        });
      });

      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fs = FirebaseFirestore.instance;
    final postRef = fs.collection('community').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    try {
      await fs.runTransaction((tx) async {
        final cSnap = await tx.get(commentRef);
        if (!cSnap.exists) return;

        final data = cSnap.data() as Map<String, dynamic>;
        final author = (data['author'] as Map<String, dynamic>?) ?? {};
        final authorUid = (author['uid'] ?? '').toString();

        // 내 댓글만 삭제
        if (authorUid != user.uid) return;

        tx.delete(commentRef);
        tx.update(postRef, {
          'commentCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtClient': DateTime.now().millisecondsSinceEpoch,
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 삭제 실패: $e')),
      );
    }
  }

  Future<void> _addReply({
    required String postId,
    required String commentId,
  }) async {

    final postSnap = await FirebaseFirestore.instance
        .collection('community')
        .doc(postId)
        .get();

    final postData = postSnap.data() ?? {};
    final postAuthorDeleted = (postData['authorDeleted'] == true) ||
        ((postData['author'] is Map) && ((postData['author']['deleted'] == true)));

    if (postAuthorDeleted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('탈퇴한 사용자의 글에는 답글을 작성할 수 없습니다.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ctrl = _replyCtrlOf(commentId);
    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sendingReply.add(commentId));

    try {
      final fs = FirebaseFirestore.instance;

      final userSnap = await fs.collection('users').doc(user.uid).get();
      final u = userSnap.data() ?? {};

      final author = {
        'uid': user.uid,
        'nickName': (u['nickName'] ?? u['nickname'] ?? '익명').toString(),
        'profile_image_url': (u['profile_image_url'] ?? '').toString(),
      };

      final commentRef = fs
          .collection('community').doc(postId)
          .collection('comments').doc(commentId);

      final replyRef = commentRef.collection('replies').doc();

      await fs.runTransaction((tx) async {
        tx.set(replyRef, {
          'text': text,
          'author': author,
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtClient': DateTime.now().millisecondsSinceEpoch,
        });

        // (선택) comment 문서에 replyCount 저장하고 싶으면:
        tx.update(commentRef, {
          'replyCount': FieldValue.increment(1),
        });

        // (선택) post updatedAt 갱신하고 싶으면:
        tx.update(fs.collection('community').doc(postId), {
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtClient': DateTime.now().millisecondsSinceEpoch,
        });
      });

      ctrl.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('답글 저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingReply.remove(commentId));
    }
  }

  Future<void> _deleteReply({
    required String postId,
    required String commentId,
    required String replyId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fs = FirebaseFirestore.instance;

    final commentRef = fs
        .collection('community').doc(postId)
        .collection('comments').doc(commentId);

    final replyRef = commentRef.collection('replies').doc(replyId);

    try {
      await fs.runTransaction((tx) async {
        final rSnap = await tx.get(replyRef);
        if (!rSnap.exists) return;

        final data = rSnap.data() as Map<String, dynamic>;
        final author = (data['author'] as Map<String, dynamic>?) ?? {};
        final authorUid = (author['uid'] ?? '').toString();

        if (authorUid != user.uid) return;

        tx.delete(replyRef);

        // replyCount -1 (선택)
        tx.update(commentRef, {
          'replyCount': FieldValue.increment(-1),
        });

        tx.update(fs.collection('community').doc(postId), {
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtClient': DateTime.now().millisecondsSinceEpoch,
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('답글 삭제 실패: $e')),
      );
    }
  }

  DateTime? _readCommentTime(Map<String, dynamic> data) {
    final v = data['createdAt'];
    if (v is Timestamp) return v.toDate();
    final c = data['createdAtClient'];
    if (c is int) return DateTime.fromMillisecondsSinceEpoch(c);
    return null;
  }

  final Map<String, bool> _replyOpen = {};
  final Map<String, TextEditingController> _replyCtrls = {};
  final Set<String> _sendingReply = {};

  @override
  void dispose() {
    _commentCtrl.dispose();
    for (final c in _replyCtrls.values) {
      c.dispose();
    }
    _disposePlayer();
    super.dispose();
  }

  TextEditingController _replyCtrlOf(String commentId) {
    return _replyCtrls.putIfAbsent(commentId, () => TextEditingController());
  }

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

    final category = (data['category'] ?? '').toString();
    final bool isNotice = category == '공지사항';

    final authorMap = (data['author'] as Map<String, dynamic>?) ?? {};
    final bool authorDeleted =
        (data['authorDeleted'] == true) || (authorMap['deleted'] == true);

    final authorName = authorDeleted
        ? '탈퇴한 사용자'
        : (authorMap['nickName'] ?? authorMap['name'] ?? '익명').toString();

    final authorProfile = authorDeleted
        ? ''
        : (authorMap['profile_image_url'] ?? '').toString();

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

    final likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
    final viewCount = (data['viewCount'] as num?)?.toInt() ?? 0;

    final place = (data['place'] as Map?)?.cast<String, dynamic>();

    final weather = (data['weather'] as Map?)?.cast<String, dynamic>();
    final temp = (weather?['temp'] as num?)?.toDouble();

    final String weatherLabel =
    (temp == null) ? '' : '온도 ${temp.round()}°';

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
              if (!isNotice) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text('$viewCount', style: const TextStyle(fontSize: 12)),

                      const SizedBox(width: 12),
                      _likeButton(doc.id, likeCount, authorDeleted: authorDeleted),
                    ],
                  ),
                ),
              ],
              if (!isNotice)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  padding: EdgeInsets.zero,
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityEdit(docId: doc.id),
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

                                if (context.mounted) Navigator.of(context).pop();
                                if (mounted) Navigator.of(this.context).pop();
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
        if (!isNotice) _placeMapWidget(place, weatherLabel),

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

              if (authorDeleted)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: const Text(
                    "탈퇴한 사용자의 글에는 댓글을 작성할 수 없습니다.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else
                _commentInput(doc, data),

              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('community')
                    .doc(doc.id)
                    .collection('comments')
                    .orderBy('createdAt', descending: false)
                    .limit(50)
                    .snapshots(),
                builder: (context, csnap) {
                  if (!csnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  final items = csnap.data!.docs;

                  if (items.isEmpty) {
                    // ✅ 탈퇴한 사용자의 글이면 "첫 댓글..." 문구 숨김
                    if (authorDeleted) {
                      return const SizedBox.shrink();
                    }

                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "첫 댓글을 남겨보세요.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  }

                  return Column(
                    children: items.map((c) {
                      final cdata = c.data() as Map<String, dynamic>;
                      final author = (cdata['author'] as Map<String, dynamic>?) ?? {};
                      final name = (author['nickName'] ?? '익명').toString();
                      final profile = (author['profile_image_url'] ?? '').toString();
                      final uid = (author['uid'] ?? '').toString();
                      final isMe = FirebaseAuth.instance.currentUser?.uid == uid;

                      final dt = _readCommentTime(cdata);
                      final when = dt == null ? "" : _timeAgoFromTs(dt);
                      final text = (cdata['text'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black12,
                              backgroundImage:
                              profile.isNotEmpty ? NetworkImage(profile) : null,
                              child: profile.isEmpty
                                  ? const Icon(Icons.person, size: 14, color: Colors.black54)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (when.isNotEmpty)
                                          Text(
                                            when,
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        if (isMe) ...[
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text('댓글 삭제'),
                                                  content: const Text('삭제하시겠습니까?'),
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
                                              if (ok == true) {
                                                await _deleteComment(
                                                  postId: doc.id,
                                                  commentId: c.id,
                                                );
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              child: Icon(Icons.delete_outline, size: 16),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      text,
                                      style: const TextStyle(fontSize: 13, height: 1.35),
                                    ),
                                    const SizedBox(height: 8),

                                    if (!authorDeleted)
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            // 답글 입력창 토글
                                            setState(() {
                                              _replyOpen[c.id] = !(_replyOpen[c.id] ?? false);
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Text(
                                              "답글",
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () {
                                            // 답글 보기(=펼치기) 토글 (인스타 느낌)
                                            setState(() {
                                              _replyOpen[c.id] = !(_replyOpen[c.id] ?? false);
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Text(
                                              (_replyOpen[c.id] ?? false) ? "답글 접기" : "답글 보기",
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

// ✅ 펼쳐졌을 때만 로드
                                    if (!authorDeleted && (_replyOpen[c.id] ?? false)) ...[
                                      const SizedBox(height: 8),

                                      // 답글 입력
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.black12),
                                          borderRadius: BorderRadius.circular(10),
                                          color: Colors.white,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _replyCtrlOf(c.id),
                                                decoration: const InputDecoration(
                                                  hintText: "답글을 입력하세요...",
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                ),
                                                minLines: 1,
                                                maxLines: 3,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _sendingReply.contains(c.id)
                                                ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                                : IconButton(
                                              onPressed: () => _addReply(
                                                postId: doc.id,
                                                commentId: c.id,
                                              ),
                                              icon: const Icon(Icons.send, size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // 답글 목록
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('community')
                                            .doc(doc.id)
                                            .collection('comments')
                                            .doc(c.id)
                                            .collection('replies')
                                            .orderBy('createdAt', descending: false)
                                            .limit(50)
                                            .snapshots(),
                                        builder: (context, rsnap) {
                                          if (!rsnap.hasData) {
                                            return const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 6),
                                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                            );
                                          }

                                          final replies = rsnap.data!.docs;
                                          if (replies.isEmpty) {
                                            return const Text(
                                              "답글이 없습니다.",
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            );
                                          }

                                          return Column(
                                            children: replies.map((r) {
                                              final rdata = r.data() as Map<String, dynamic>;
                                              final rauthor = (rdata['author'] as Map<String, dynamic>?) ?? {};
                                              final rname = (rauthor['nickName'] ?? '익명').toString();
                                              final rprofile = (rauthor['profile_image_url'] ?? '').toString();
                                              final ruid = (rauthor['uid'] ?? '').toString();
                                              final isMeReply = FirebaseAuth.instance.currentUser?.uid == ruid;

                                              final rdt = _readCommentTime(rdata);
                                              final rwhen = rdt == null ? "" : _timeAgoFromTs(rdt);
                                              final rtext = (rdata['text'] ?? '').toString();

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const SizedBox(width: 18), // ✅ 들여쓰기
                                                    CircleAvatar(
                                                      radius: 10,
                                                      backgroundColor: Colors.black12,
                                                      backgroundImage:
                                                      rprofile.isNotEmpty ? NetworkImage(rprofile) : null,
                                                      child: rprofile.isEmpty
                                                          ? const Icon(Icons.person, size: 12, color: Colors.black54)
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Container(
                                                        padding: const EdgeInsets.all(9),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          border: Border.all(color: Colors.black12),
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    rname,
                                                                    style: const TextStyle(
                                                                      fontSize: 12,
                                                                      fontWeight: FontWeight.w700,
                                                                    ),
                                                                  ),
                                                                ),
                                                                if (rwhen.isNotEmpty)
                                                                  Text(
                                                                    rwhen,
                                                                    style: const TextStyle(
                                                                      fontSize: 11,
                                                                      color: Colors.grey,
                                                                    ),
                                                                  ),
                                                                if (isMeReply) ...[
                                                                  const SizedBox(width: 6),
                                                                  InkWell(
                                                                    onTap: () async {
                                                                      final ok = await showDialog<bool>(
                                                                        context: context,
                                                                        builder: (_) => AlertDialog(
                                                                          title: const Text('답글 삭제'),
                                                                          content: const Text('삭제하시겠습니까?'),
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
                                                                      if (ok == true) {
                                                                        await _deleteReply(
                                                                          postId: doc.id,
                                                                          commentId: c.id,
                                                                          replyId: r.id,
                                                                        );
                                                                      }
                                                                    },
                                                                    child: const Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                      child: Icon(Icons.delete_outline, size: 16),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                            const SizedBox(height: 6),
                                                            Text(
                                                              rtext,
                                                              style: const TextStyle(fontSize: 13, height: 1.3),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
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

  Widget _commentInput(DocumentSnapshot doc, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                hintText: "댓글을 입력하세요...",
                border: InputBorder.none,
                isDense: true,
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 8),
          _sendingComment
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : IconButton(
            onPressed: () => _addComment(postDoc: doc, postData: data),
            icon: const Icon(Icons.send, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
