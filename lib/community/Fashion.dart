import 'package:flutter/material.dart';
import 'CommunityAdd.dart';

class Fashion extends StatelessWidget {
  const Fashion({super.key});

  // ✅ 일단 하드코딩 데이터
  static const List<Map<String, dynamic>> posts = [
    {
      "title": "오늘 패딩 뭐 입으셨어요?",
      "author": "모카",
      "time": "6분전",
      "views": 14,
      "comments": 2,
    },
    {
      "title": "겨울에 코트 vs 패딩",
      "author": "소라",
      "time": "12분전",
      "views": 31,
      "comments": 5,
    },
    {
      "title": "출근룩 이렇게 입으면 어떤가요?",
      "author": "민지",
      "time": "21분전",
      "views": 22,
      "comments": 4,
    },
    {
      "title": "니트 추천 좀 해주세요",
      "author": "하루",
      "time": "29분전",
      "views": 17,
      "comments": 1,
    },
    {
      "title": "겨울 부츠 어디서 사세요?",
      "author": "루나",
      "time": "41분전",
      "views": 26,
      "comments": 3,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListView.separated(
            itemCount: posts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final post = posts[index];

              return InkWell(
                onTap: () {
                  // ✅ 나중에 상세페이지 만들면 여기서 push
                  // Navigator.push(...);
                },
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post["title"],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            post["author"],
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
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
    );
  }
}
