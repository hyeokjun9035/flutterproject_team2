import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/community/CommunityView.dart';
import '../headandputter/putter.dart';
import 'CommunityAdd.dart';
import 'Event.dart';
import 'Chatter.dart';
import 'Fashion.dart';
import 'Notice.dart';

import 'package:firebase_auth/firebase_auth.dart'; // ✅ 추가

import '../widgets/app_drawer_factory.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String _timeAgo(dynamic createdAt) {
    if (createdAt == null || createdAt is! Timestamp) return '';

    final dt = createdAt.toDate();
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    final userStream = (firebaseUser == null)
        ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).snapshots();

    return PutterScaffold(
      currentIndex: 1,
      body: Scaffold(
        backgroundColor: Colors.grey[200],

        // ✅ Drawer 추가
        drawer: (firebaseUser == null)
            ? null
            : AppDrawerFactory.buildBasic(
          context: context,
          userStream: userStream,
          locationLabel: null, // 커뮤니티 페이지에 위치라벨 없으면 null
          isHome: false,
          onGoHome: () {
            // ✅ 홈이 따로 라우트면 아래로 교체:
            Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
          },
          // (선택) 커뮤니티 페이지에서는 "내 주변 지도" 눌렀을 때 막기
          onGoNearbyMapOverride: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('홈에서 위치를 불러온 뒤 사용해주세요.')),
            );
          },
        ),

        // (선택) Drawer 열릴 때 화면이 너무 어두우면 조절
        drawerScrimColor: Colors.black54,

        appBar: AppBar(
          backgroundColor: Colors.grey[200],

          // ✅ 메뉴 버튼으로 Drawer 열기 (Builder 필수)
          leading: Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),

          title: const Text("커뮤니티"),
          elevation: 0,
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

        body: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 공지사항
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    width: 400,
                    height: 270,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white,
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Notice()),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "공지사항",
                            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 2, color: Colors.grey),
                          const SizedBox(height: 10),

                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('community')
                                .where("category", isEqualTo: "공지사항")
                                .orderBy('createdAt', descending: true)
                                .limit(3)
                                .snapshots(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const CircularProgressIndicator();

                              final docs = snap.data!.docs;

                              return Column(
                                children: docs.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;

                                  final title = (data['title'] ?? '').toString();

                                  final authorMap =
                                      (data['author'] as Map<String, dynamic>?) ?? {};
                                  final authorName =
                                  (authorMap['nickName'] ?? authorMap['name'] ?? '익명')
                                      .toString();

                                  final views = (data['viewCount'] ?? 0);
                                  final comments = (data['commentCount'] ?? 0);

                                  final createdAt = data['createdAt'];
                                  final timeText = _timeAgo(createdAt);

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => Communityview(docId: doc.id),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                "$authorName | $timeText | ",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const Icon(Icons.remove_red_eye_outlined,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 3),
                                              Text(
                                                "$views | ",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const Icon(Icons.comment_outlined,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 3),
                                              Text(
                                                "$comments",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 사건/이슈
                Container(
                  padding: const EdgeInsets.all(20),
                  width: 400,
                  height: 270,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white,
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Event()),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "사건/이슈",
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 2, color: Colors.grey),
                        const SizedBox(height: 10),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('community')
                              .where("category", isEqualTo: "사건/이슈")
                              .orderBy('createdAt', descending: true)
                              .limit(3)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) return const CircularProgressIndicator();

                            final docs = snap.data!.docs;

                            return Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;

                                final title = (data['title'] ?? '').toString();

                                final authorMap =
                                    (data['author'] as Map<String, dynamic>?) ?? {};
                                final authorName =
                                (authorMap['nickName'] ?? authorMap['name'] ?? '익명')
                                    .toString();

                                final views = (data['viewCount'] ?? 0);
                                final comments = (data['commentCount'] ?? 0);

                                final createdAt = data['createdAt'];
                                final timeText = _timeAgo(createdAt);

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Communityview(docId: doc.id),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              "$authorName | $timeText | ",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Icon(Icons.remove_red_eye_outlined,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text(
                                              "$views | ",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Icon(Icons.comment_outlined,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text(
                                              "$comments",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 수다
                Container(
                  padding: const EdgeInsets.all(20),
                  width: 400,
                  height: 270,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white,
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Chatter()),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "수다",
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 2, color: Colors.grey),
                        const SizedBox(height: 10),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('community')
                              .where("category", isEqualTo: "수다")
                              .orderBy('createdAt', descending: true)
                              .limit(3)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) return const CircularProgressIndicator();

                            final docs = snap.data!.docs;

                            return Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;

                                final title = (data['title'] ?? '').toString();

                                final authorMap =
                                    (data['author'] as Map<String, dynamic>?) ?? {};
                                final authorName =
                                (authorMap['nickName'] ?? authorMap['name'] ?? '익명')
                                    .toString();

                                final views = (data['viewCount'] ?? 0);
                                final comments = (data['commentCount'] ?? 0);

                                final createdAt = data['createdAt'];
                                final timeText = _timeAgo(createdAt);

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Communityview(docId: doc.id),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              "$authorName | $timeText | ",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Icon(Icons.remove_red_eye_outlined,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text(
                                              "$views | ",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Icon(Icons.comment_outlined,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text(
                                              "$comments",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 패션
                Container(
                  padding: const EdgeInsets.all(20),
                  width: 400,
                  height: 270,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white,
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Fashion()),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "패션",
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 2, color: Colors.grey),
                        const SizedBox(height: 10),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('community')
                              .where("category", isEqualTo: "패션")
                              .orderBy('createdAt', descending: true)
                              .limit(3)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) return const CircularProgressIndicator();

                            final docs = snap.data!.docs;

                            return Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;

                                final title = (data['title'] ?? '').toString();

                                final authorMap =
                                    (data['author'] as Map<String, dynamic>?) ?? {};
                                final authorName =
                                (authorMap['nickName'] ?? authorMap['name'] ?? '익명')
                                    .toString();

                                final views = (data['viewCount'] ?? 0);
                                final comments = (data['commentCount'] ?? 0);

                                final createdAt = data['createdAt'];
                                final timeText = _timeAgo(createdAt);

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Communityview(docId: doc.id),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              "$authorName | $timeText | ",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Icon(Icons.remove_red_eye_outlined,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text(
                                              "$views | ",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Icon(Icons.comment_outlined,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text(
                                              "$comments",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
