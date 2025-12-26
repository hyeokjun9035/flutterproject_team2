import 'package:flutter/material.dart';
import 'userEdit.dart';
import 'myPosts.dart';
import 'locationSettings.dart';
import 'communitySettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../headandputter/putter.dart'; //jgh251226

class UserMypage extends StatelessWidget {
  const UserMypage({super.key});

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;
    return PutterScaffold(
      currentIndex: 2,
      body: Scaffold(
        backgroundColor: Colors.white,
          body: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid) // 아까 넣은 UID 문서번호
                  .snapshots(),
              builder: (context, snapshot) {
                // 데이터 로딩 중 처리
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }


                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("사용자 정보를 찾을 수 없습니다."));
                }


                var userData = snapshot.data!.data() as Map<String, dynamic>;



                return Column(
                  children: [
                    // 상단 프로필 영역
                    Container(
                      padding: const EdgeInsets.only(
                          top: 60, bottom: 40, left: 20, right: 20),
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.limeAccent,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Icon(Icons.format_list_bulleted, size: 24,
                                  color: Colors.black54),
                              Icon(Icons.person, size: 35, color: Colors.black),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              const CircleAvatar(
                                radius: 60,
                                backgroundColor: Color(0xFFE0E0E0),
                                child: Text("프로필", style: TextStyle(
                                    color: Colors.black54, fontSize: 16)),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const UserEdit()),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black12,
                                        blurRadius: 4)
                                    ],
                                  ),
                                  child: const Icon(
                                      Icons.edit, size: 20, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userData['name'] ?? "이름 없음",
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline),
                          ),
                          const SizedBox(height: 8),
                          // 5. Firestore의 'nickname' 데이터 출력
                          Text(
                            userData['nickname'] ?? "닉네임 없음",
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),

                    // 하단 리스트 영역
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        children: [
                          // 수정 포인트 1: context를 인자로 전달함
                          _buildMenuButton(
                              context, Icons.description_outlined, "내가 작성한 게시글"),
                          _buildMenuButton(
                              context, Icons.location_on_outlined, "위치 설정"),
                          _buildMenuButton(
                              context, Icons.settings_outlined, "커뮤니티 설정"),

                          TextButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut(); //
                              Navigator.pop(context); // 로그인 페이지로 돌아가기
                            },
                            child: const Text(
                                "로그아웃", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }, // builder 끝
          ), // StreamBuilder 끝
      ),
    );
  }

  // 수정 포인트 2: BuildContext 인자를 추가함
  Widget _buildMenuButton(BuildContext context, IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black87),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing: const Icon(Icons.arrow_forward, color: Colors.black),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        onTap: () {
          if (title == "내가 작성한 게시글") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyPosts()),
            );
          } else if (title == "위치 설정") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LocationSettings()),
            );
          } else if (title == "커뮤니티 설정") {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CommunitySettings()),
            );
                }
            },
      ),
    );
  }
}