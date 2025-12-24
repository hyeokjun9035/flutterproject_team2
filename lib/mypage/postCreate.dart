import 'package:flutter/material.dart';
import 'postDetail.dart';
class PostCreate extends StatelessWidget {
  const PostCreate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소", style: TextStyle(color: Colors.black, fontSize: 16)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PostDetail()),
              );
            },
            child: const Text("다음", style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("-게시글", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 사진 업로드 안내 영역
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: const Center(
                child: Text(
                  "현재 교통과 관련 사진을 올려주세요",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("-갤린더", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 30),
                ),
              ],
            ),

            // 갤러리 이미지 그리드 (이미지 예시)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemCount: 6, // 이미지 개수
              itemBuilder: (context, index) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.white), // 실제 이미지로 대체 가능
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}