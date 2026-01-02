import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/community/CommunityView.dart' hide Communityview;
import 'CommunityAdd.dart';
import '../headandputter/putter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'CommunityEdit.dart';
import 'CommunityView.dart';

class Notice extends StatefulWidget {
  const Notice({super.key});

  // ✅ 일단 하드코딩 데이터
  static const List<Map<String, dynamic>> posts = [];

  @override
  State<Notice> createState() => _NoticeState();
}

class _NoticeState extends State<Notice> {
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

                  // author는 Map으로 저장했으니 문자열로 바로 못 씀
                  final authorMap = (data["author"] as Map<String, dynamic>?) ?? {};
                  final authorName = (authorMap["nickName"] ?? authorMap["name"] ?? "익명").toString();
                  final authorProfile = (authorMap['profile_image_url'] ?? '').toString();

                  final placeMap = (data["place"] as Map<String, dynamic>?) ?? {};
                  final placeName = (placeMap["name"] ?? "").toString().trim();
                  final placeAddress = (placeMap["address"] ?? "").toString().trim();

                  final weatherMap = (data["weather"] as Map<String, dynamic>?) ?? {};
                  final temp = weatherMap["temp"]; // _addCommunity에서 'weather': {'temp': _temp ...}

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
                          crossAxisAlignment: CrossAxisAlignment.start, // 위로 붙게
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black12,
                              backgroundImage: authorProfile.isNotEmpty ? NetworkImage(authorProfile) : null,
                              child: authorProfile.isEmpty
                                  ? const Icon(Icons.person, size: 16, color: Colors.black54)
                                  : null,
                            ),
                            const SizedBox(width: 8),

                            // ✅ 닉네임 + 위치를 Column으로 묶기
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    authorName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.0),
                                  ),

                                  if (locationLabel.isNotEmpty || weatherLabel.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1), // 여기 0~2로 조절
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (locationLabel.isNotEmpty) ...[
                                            const Icon(Icons.location_on_outlined, size: 16),
                                            Flexible(
                                              child: Text(
                                                locationLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ],
                                          if (locationLabel.isNotEmpty && weatherLabel.isNotEmpty)
                                            const SizedBox(width: 5),
                                          if (weatherLabel.isNotEmpty) ...[
                                            const Icon(Icons.thermostat, size: 16),
                                            Text(
                                              weatherLabel,
                                              style: const TextStyle(fontSize: 14),
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
                              onSelected: (value) {
                                if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CommunityEdit()),
                                  );
                                }

                                if (value == 'delete') {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text("삭제?"),
                                        content: const Text("정말 삭제하시겠습니까?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () async {
                                              // ✅ 여기서 삭제 실행
                                              print(doc.id);
                                              await FirebaseFirestore.instance
                                                  .collection("community")
                                                  .doc(doc.id)
                                                  .delete();
                                              // ✅ 다이얼로그 닫기ㅁ
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text("삭제"),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
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
                            ],
                          ),
                        ),

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
              ),
            );
          },
        ),
      ),
    );
  }
}
