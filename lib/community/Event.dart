import 'package:flutter/material.dart';
import 'CommunityAdd.dart';

class Event extends StatelessWidget {
  const Event({super.key});

  // ✅ 일단 하드코딩 데이터
  static const List<Map<String, dynamic>> posts = [
    {
      "title": "출근길에 폭설이 왔어요",
      "author": "반딧이",
      "time": "3분전",
      "views": 3,
      "comments": 0,
    },
    {
      "title": "눈때문에 길이 미끄러워서 차사고가 났네요",
      "author": "초코볼",
      "time": "8분전",
      "views": 12,
      "comments": 2,
    },
    {
      "title": "눈 때문에 전철 멈췄어요!",
      "author": "이보리",
      "time": "13분전",
      "views": 41,
      "comments": 5,
    },
    {
      "title": "미세먼지 심해요… 마스크 꼭 쓰세요",
      "author": "구름",
      "time": "20분전",
      "views": 18,
      "comments": 1,
    },
    {
      "title": "사거리 신호 고장났대요 우회하세요",
      "author": "도토리",
      "time": "32분전",
      "views": 27,
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
