import 'package:flutter/material.dart';
import 'postCreate.dart';
import 'DetailMypost.dart';
class MyPosts extends StatelessWidget {
  const MyPosts({super.key});

  @override
  Widget build(BuildContext context) {
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
            // 1. 날씨 정보 영역
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
                    MaterialPageRoute(builder: (context) => const PostCreate()), // 작성 페이지로 이동
                  );
                },
                child: Container(
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

            // 3. 작성한 게시글 그리드 뷰
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

            // 이미지 그리드 (2열)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 이미지처럼 3열로 구성
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemCount: 6, // 예시 이미지 6개
              itemBuilder: (context, index) {
                final String currentImageUrl = 'https://picsum.photos/200?random=$index';

                return GestureDetector(
                  onTap: () {
                    // 클릭 시 상세 페이지로 이동하며 이미지 URL 전달
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Detailmypost(imageUrl: currentImageUrl),
                      ),
                    );
                  },
                  child: Container(
                    color: Colors.grey[300],
                    child: Image.network(
                      currentImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}