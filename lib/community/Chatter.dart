import 'package:flutter/material.dart';

class Chatter extends StatelessWidget {
  const Chatter({super.key});

  // ✅ 일단 하드코딩 데이터
  static const List<Map<String, dynamic>> posts = [
    {
      "title": "출근하기 너무 힘드네요 ㅠㅠ",
      "author": "하늘",
      "time": "5분전",
      "views": 7,
      "comments": 1,
    },
    {
      "title": "2호선 진짜 지옥이에요",
      "author": "지수",
      "time": "11분전",
      "views": 23,
      "comments": 4,
    },
    {
      "title": "오늘 점심 뭐 드셨어요?",
      "author": "토끼",
      "time": "18분전",
      "views": 12,
      "comments": 3,
    },
    {
      "title": "카페 신상 메뉴 마셔봤어요",
      "author": "민트",
      "time": "27분전",
      "views": 19,
      "comments": 2,
    },
    {
      "title": "요즘 잠이 너무 많아요",
      "author": "구름",
      "time": "39분전",
      "views": 9,
      "comments": 0,
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
          "수다",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // 나중에 글쓰기/추가 기능 붙일 자리
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
