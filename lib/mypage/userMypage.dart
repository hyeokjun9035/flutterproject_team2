import 'package:flutter/material.dart';
import 'userEdit.dart';
import 'myPosts.dart';
import 'locationSettings.dart';
import 'communitySettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/join/login.dart';

import 'package:flutter_project/headandputter/putter.dart';
import 'package:flutter_project/home/home_page.dart';

class UserMypage extends StatelessWidget {
  const UserMypage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;


    return PutterScaffold(
      currentIndex: 2,
      body: Container(
        color: Colors.white,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData  || !snapshot.data!.exists) {
              return const Center(child: Text("사용자 정보를 찾을 수 없습니다."));
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>;


            return Column(
              children: [

                Container(
                  padding: const EdgeInsets.only(top: 60, bottom: 40, left: 20, right: 20),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF29B6F6), // 진한 하늘색
                        Color(0xFFB3E5FC), // 아주 연한 하늘색
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          // Icon(Icons.format_list_bulleted, size: 24, color: Colors.black54),
                          // Icon(Icons.person, size: 35, color: Colors.black),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: const Color(0xFF4FC3F7),
                            backgroundImage: (userData['profile_image_url'] != null &&
                                userData['profile_image_url'].toString().isNotEmpty)
                                ? NetworkImage(userData['profile_image_url'])
                                : null,
                            child: (userData['profile_image_url'] == null ||
                                userData['profile_image_url'].toString().isEmpty)
                                ? const Icon(Icons.person, size: 60, color: Colors.white)
                                : null,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const UserEdit()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: const Icon(Icons.edit, size: 20, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userData['name'] ?? "이름 없음",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userData['nickName'] ?? "닉네임 없음",
                        style: const TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    ],
                  ),
                ),

                // 하단 리스트 영역
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    children: [
                      _buildMenuButton(context, Icons.description_outlined, "내가 작성한 게시글"),
                      _buildMenuButton(context, Icons.location_on_outlined, "위치 설정"),
                      _buildMenuButton(context, Icons.settings_outlined, "커뮤니티 설정"),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                                  (route) => false,
                            );
                          }
                        },
                        child: const Text("로그아웃", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 메뉴 버튼 헬퍼
  Widget _buildMenuButton(BuildContext context, IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.white, width: 1),
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPosts()));
          } else if (title == "위치 설정") {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationSettings()));
          } else if (title == "커뮤니티 설정") {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunitySettings()));
          }
        },
      ),
    );
  }
}