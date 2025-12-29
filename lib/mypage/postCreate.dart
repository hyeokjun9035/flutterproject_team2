import 'package:flutter/material.dart';
import 'dart:io'; // File 클래스 사용을 위해 필수
import 'package:image_picker/image_picker.dart'; // 이미지 피커 라이브러리
import 'postDetail.dart';

class PostCreate extends StatefulWidget {
  const PostCreate({super.key});

  @override
  State<PostCreate> createState() => _PostCreateState();
}

class _PostCreateState extends State<PostCreate> {
  final ImagePicker _picker = ImagePicker();

  // 타입을 File로 설정하여 타입 충돌 에러를 방지합니다.
  List<File> _selectedImages = [];

  // 갤러리에서 여러 장의 이미지를 가져오는 함수
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          // XFile 리스트를 File 리스트로 즉시 변환하여 화면을 갱신합니다.
          _selectedImages = images.map((xFile) => File(xFile.path)).toList();
        });
      }
    } catch (e) {
      print("이미지 선택 에러: $e");
    }
  }

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
            onPressed: _selectedImages.isEmpty
                ? null // 사진이 없으면 버튼 비활성화
                : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // 선택된 이미지 리스트를 다음 페이지로 전달
                  builder: (context) => PostDetail(images: _selectedImages),
                ),
              );
            },
            child: Text(
                "다음",
                style: TextStyle(
                    color: _selectedImages.isEmpty ? Colors.grey : Colors.black,
                    fontSize: 16
                )
            ),
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

            // 상단 큰 이미지 미리보기 (첫 번째 사진)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
                color: Colors.grey[100],
              ),
              child: _selectedImages.isEmpty
                  ? const Center(child: Text("현재 교통과 관련 사진을 올려주세요"))
                  : Image.file(_selectedImages[0], fit: BoxFit.cover),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("-갤러리", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _pickImages, // 클릭 시 갤러리 열기
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 30),
                ),
              ],
            ),

            // 선택된 이미지들을 보여주는 격자 뷰
            _selectedImages.isEmpty
                ? Container(
              height: 100,
              alignment: Alignment.center,
              child: const Text("선택된 사진이 없습니다.", style: TextStyle(color: Colors.grey)),
            )
                : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImages[index],
                    fit: BoxFit.cover,
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