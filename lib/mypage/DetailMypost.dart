import 'package:flutter/material.dart';
import 'package:flutter_project/mypage/postDelete.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Detailmypost extends StatelessWidget {
  final String imageUrl;
  final Map<String, dynamic> postData; // 게시글 데이터 전체
  final String postId; // 문서 ID

  const Detailmypost({
    super.key,
    required this.imageUrl,
    required this.postData,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    // 날짜 변환 로직
    String dateStr = "";
    if (postData['cdate'] != null) {
      DateTime dt = (postData['cdate'] as Timestamp).toDate();
      dateStr = DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("게시글 자세히 보기",
            style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 프로필 영역 (실시간 데이터 연동)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: FutureBuilder<DocumentSnapshot>(
                // 게시글에 담긴 user_id를 기준으로 users 컬렉션에서 정보를 가져옴
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(postData['user_id'])
                    .get(),
                builder: (context, snapshot) {
                  // 기본값 (데이터를 불러오기 전이나 실패 시)
                  String userNickname = "사용자";
                  String profileImg = 'https://picsum.photos/100'; // 기본 프로필

                  if (snapshot.hasData && snapshot.data!.exists) {
                    var userData = snapshot.data!.data() as Map<String, dynamic>;
                    // 🔥 users 테이블 필드명인 'nickname'과 'profile_image_url' 적용
                    userNickname = userData['nickname'] ?? "이름없음";
                    profileImg = userData['profile_image_url'] ?? profileImg;
                  }

                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(profileImg),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🔥 연동된 닉네임 출력
                            Text(userNickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Postdelete(
                                postId: postId,
                                initialData: postData,

                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text("수정/삭제", style: TextStyle(fontSize: 12, color: Colors.blue)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 2. 메인 이미지
            Image.network(imageUrl, width: double.infinity, height: 300, fit: BoxFit.cover),

            // 3. 게시글 정보 및 본문
            Container(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark_border, size: 20),
                      const SizedBox(width: 5),
                      Text(postData['board_type'] ?? "일반", style: const TextStyle(color: Colors.black87)),
                      const SizedBox(width: 15),
                      const Icon(Icons.location_on_outlined, size: 20),
                      const SizedBox(width: 5),
                      const Text("부평역", style: TextStyle(color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    postData['content'] ?? "내용이 없습니다.",
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text("공유하기"),
                  ),
                ],
              ),
            ),
            const Divider(),
            // 4. 댓글 입력창
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "댓글 입력해주세요",
                  suffixIcon: const Icon(Icons.send),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}