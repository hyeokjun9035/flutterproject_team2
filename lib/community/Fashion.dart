import 'package:flutter/material.dart';
import 'CommunityAdd.dart';
import '../headandputter/putter.dart';

class Fashion extends StatelessWidget {
  const Fashion({super.key});

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
            "패션",
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
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            child: ListView.separated(
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final post = posts[index];

                return InkWell(
                  onTap: () {
                    // ✅ 나중에 상세페이지 만들면 여기서 push
                    // Navigator.push(...);
                  },
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            Text(
                              (post["author"] ?? "").toString(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                                onPressed: (){},
                                icon: Icon(Icons.more_vert)
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post["title"],
                          style: const TextStyle(fontSize: 14),
                        ),

                        const SizedBox(height: 10),
                        // ✅ 큰 이미지
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.asset(
                              (post["image"] ?? "").toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Text("이미지 없음"),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Text(
                              post["time"],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.remove_red_eye_outlined,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              "${post["views"]}",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.comment_outlined,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              "${post["comments"]}",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
