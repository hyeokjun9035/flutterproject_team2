import 'package:flutter/material.dart';
import '../headandputter/putter.dart';
import 'CommunityAdd.dart';
import 'Event.dart';
import 'Chatter.dart';
import 'Fashion.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CommunityPageState(

    );
  }
}

// ✅ home에 들어갈 "화면"은 Widget이어야 함
class CommunityPageState extends StatelessWidget {
  const CommunityPageState({super.key});

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 1,
      body: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          backgroundColor: Colors.grey[200],
          leading: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.menu)
          ),
          title: const Text("커뮤니티"),
          elevation: 0,
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
                icon: const Icon(Icons.add)
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Center(

                //사건/이슈
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
                        Divider(height: 2, color: Colors.grey,),
                        const SizedBox(height: 10),

                        // ✅ 여기서 최신글 3개 출력
                        ...Event.posts.take(3).map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p["title"],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "${p["author"]} | ${p["time"]} | ",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 3),
                                    Text("${p["views"]} | ",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const Icon(Icons.comment_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 3),
                                    Text("${p["comments"]}",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10,),

              //수다
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
                      Divider(height: 2, color: Colors.grey,),
                      const SizedBox(height: 10),

                      // ✅ 여기서 최신글 3개 출력
                      ...Event.posts.take(3).map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p["title"],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              Row(
                                children: [
                                  Text(
                                    "${p["author"]} | ${p["time"]} | ",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Text("${p["views"]} | ",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const Icon(Icons.comment_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Text("${p["comments"]}",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10,),
              //패션
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
                      Divider(height: 2, color: Colors.grey,),
                      const SizedBox(height: 10),

                      // ✅ 여기서 최신글 3개 출력
                      ...Event.posts.take(3).map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p["title"],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              Row(
                                children: [
                                  Text(
                                    "${p["author"]} | ${p["time"]} | ",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Text("${p["views"]} | ",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const Icon(Icons.comment_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Text("${p["comments"]}",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // bottomNavigationBar: BottomNavigationBar(
        //   type: BottomNavigationBarType.fixed,
        //   backgroundColor: Colors.grey[200],
        //   selectedItemColor: Colors.blue,
        //   unselectedItemColor: Colors.grey,
        //   items: const [
        //     BottomNavigationBarItem(
        //         icon: Icon(Icons.home_outlined),
        //         label: '홈'
        //     ),
        //     BottomNavigationBarItem(
        //         icon: Icon(Icons.comment),
        //         label: '커뮤니티'
        //     ),
        //     BottomNavigationBarItem(
        //         icon: Icon(Icons.person),
        //         label: '마이페이지'
        //     ),
        //     BottomNavigationBarItem(
        //         icon: Icon(Icons.notifications_active),
        //         label: '알림'
        //     ),
        //   ],
        // ),
      ),
    );
  }
}
