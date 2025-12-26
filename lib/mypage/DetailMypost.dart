import 'package:flutter/material.dart';
import 'package:flutter_project/mypage/postDelete.dart';


class Detailmypost extends StatelessWidget {
  final String imageUrl; // 클릭한 이미지 URL을 전달받음

  const Detailmypost({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
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
            // 1. 프로필 영역
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundImage: NetworkImage('https://picsum.photos/100'), // 작성자 프로필
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text("도로위 고라니", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Postdelete()),
                        );
                      },
                      child: const Text("수정하기", style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
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
                    children: const [
                      Icon(Icons.bookmark_border, size: 20),
                      SizedBox(width: 5),
                      Text("자유게시판", style: TextStyle(color: Colors.grey)),
                      SizedBox(width: 15),
                      Icon(Icons.location_on_outlined, size: 20),
                      SizedBox(width: 5),
                      Text("부평역", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("현재 날씨 ☀️ 온도: 5도, 미세먼지: 30ug/m3, 바람: 2.6m/s",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),
                  const Text("00시 부평역 주변 정체입니다 ㅜㅜ ..", style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text("공유하기"),
                  ),
                ],
              ),
            ),
            const Divider(),
            // 4. 댓글 입력창 (간이)
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "댓글 입력해주세요",
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