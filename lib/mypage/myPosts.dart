import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'postCreate.dart';
import 'DetailMypost.dart';

class MyPosts extends StatelessWidget {
  const MyPosts({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 현재 로그인한 사용자의 UID 가져오기
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("현재 날씨", style: TextStyle(color: Colors.black, fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // (생략 가능) 1. 날씨 정보 영역
            const SizedBox(height: 10),
            const Icon(Icons.wb_sunny_outlined, size: 80, color: Colors.orangeAccent),
            const SizedBox(height: 10),
            const Text("온도 : 5도 (체감온도:3도)", style: TextStyle(fontSize: 15)),
            const Text("미세먼지 : 30ug/m^3", style: TextStyle(fontSize: 15)),
            const Text("습도:47%", style: TextStyle(fontSize: 15)),
            const Text("바람: 2.6 m/s", style: TextStyle(fontSize: 15)),
            const SizedBox(height: 30),

            // 2. 게시글 작성하러 가기 버튼
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PostCreate()),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("게시글 작성하러 가기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("-현재 교통상황을 공유해보세요", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. 작성한 게시글 영역 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: const [
                    Icon(Icons.circle, size: 8, color: Colors.black),
                    SizedBox(width: 8),
                    Text("작성한 게시글", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 🔥 핵심: StreamBuilder를 통해 내 글만 실시간으로 가져오기
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community')
                  .where('user_id', isEqualTo: myUid) // 👈 내가 작성한 글만 필터링
                  .orderBy('cdate', descending: true) // 최신순 정렬
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: Text("작성한 게시글이 없습니다."),
                  );
                }

                final posts = snapshot.data!.docs;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    var postData = posts[index].data() as Map<String, dynamic>;
                    // 이미지 리스트 중 첫 번째 이미지를 대표로 보여줌
                    List<dynamic> imageUrls = postData['image_urls'] ?? [];
                    String displayUrl = imageUrls.isNotEmpty
                        ? imageUrls[0]
                        : 'https://via.placeholder.com/150'; // 이미지 없을 때 대체 이미지

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Detailmypost(
                              imageUrl: displayUrl,
                              postId: posts[index].id,
                              postData: postData,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        color: Colors.grey[200],
                        child: Image.network(
                          displayUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}