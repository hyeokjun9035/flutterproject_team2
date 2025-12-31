import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'CommunityAdd.dart';
import '../headandputter/putter.dart';

class Event extends StatelessWidget {
  const Event({super.key});

  // ✅ 일단 하드코딩 데이터
  static const List<Map<String, dynamic>> posts = [
    {
      "author": "KIMFATION2",
      "title": "오늘 많이 춥네요 오늘은 패딩 입고 출근합니다~",
      "image": "assets/joinIcon/cloud.png", // ✅ 추가
      "time": "3분전",
      "views": 3,
      "comments": 0,
    },
    {
      "author": "SONGWINTER",
      "title": "저는 겨울이 제일 좋은거 같아요~",
      "image": "assets/joinIcon/cloud.png",
      "time": "8분전",
      "views": 12,
      "comments": 2,
    },
    {
      "author": "SONGWINTER",
      "title": "저는 겨울이 제일 좋은거 같아요~",
      "image": "assets/joinIcon/sun.png",
      "time": "1분전",
      "views": 12,
      "comments": 10,
    },
  ];

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
            "사건/이슈",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => Communityadd()
                    )
                );
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("community")
              .where("category", isEqualTo: "사건/이슈")
              .orderBy("createdAt", descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                final title = (data["title"] ?? "").toString();

                // author는 Map으로 저장했으니 문자열로 바로 못 씀
                final authorMap = (data["author"] as Map<String, dynamic>?) ?? {};
                final authorName = (authorMap["nickName"] ?? authorMap["name"] ?? "익명").toString();

                final views = (data["viewCount"] ?? 0);
                final comments = (data["commentCount"] ?? 0);

                // 이미지: images 리스트의 첫번째를 보여주는 예시(없으면 null)
                final images = (data["images"] as List?) ?? [];
                final firstImageUrl = images.isNotEmpty ? images.first.toString() : null;
                final videos = (data["videos"] as List?) ?? [];
                final firstVideoUrl = videos.isNotEmpty ? videos.first.toString() : null;
                final videoThumbs = (data["videoThumbs"] as List?) ?? [];
                final firstVideoThumb = videoThumbs.isNotEmpty ? videoThumbs.first.toString() : null;
                Widget? videoPreview;
                if (firstVideoThumb != null && firstVideoThumb.isNotEmpty) {
                  videoPreview = ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(firstVideoThumb, fit: BoxFit.cover),
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
                  );
                } else if (firstVideoUrl != null && firstVideoUrl.isNotEmpty) {
                  videoPreview = ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.play_circle_fill, size: 64),
                      ),
                    ),
                  );
                }


                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black12,
                            child: Icon(Icons.person, size: 16, color: Colors.black54),
                          ),
                          const SizedBox(width: 8),
                          Text(authorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(title, style: const TextStyle(fontSize: 14)),

                      const SizedBox(height: 10),

                      // ✅ Firestore 이미지 URL이면 Image.network
                      if (firstImageUrl != null && firstImageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              firstImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Text("이미지 없음"),
                              ),
                            ),
                          ),
                        ),

                      if (videoPreview != null) ...[
                        const SizedBox(height: 10),
                        videoPreview,
                      ],

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          // createdAt을 time(“3분전”)으로 만들려면 따로 변환 로직 필요
                          Text("", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          const Spacer(),
                          Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text("$views", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(width: 10),
                          Icon(Icons.comment_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text("$comments", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
