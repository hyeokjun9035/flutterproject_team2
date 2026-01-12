import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'postDetail.dart';

class PostCreate extends StatefulWidget {
  const PostCreate({super.key});

  @override
  State<PostCreate> createState() => _PostCreateState();
}

class _PostCreateState extends State<PostCreate> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images.map((xFile) => File(xFile.path)).toList();
        });
      }
    } catch (e) {
      debugPrint("이미지 선택 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB), // 아주 연한 회색 배경
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
              "취소", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        title: const Text("사진 선택",
            style: TextStyle(color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _selectedImages.isEmpty
                  ? null
                  : () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>
                        PostDetail(images: _selectedImages)),
                  ),
              child: Text(
                "다음",
                style: TextStyle(
                  color: _selectedImages.isEmpty ? Colors.grey[300] : Colors
                      .blueAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildMainPreview(),

            const SizedBox(height: 25),


            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("내 갤러리",
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5)),
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_photo_alternate_rounded,
                          color: Colors.blueAccent, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),


            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _selectedImages.isEmpty
                  ? _buildEmptyState()
                  : _buildImageGrid(),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }


  Widget _buildMainPreview() {
    return Container(
      width: double.infinity,
      height: MediaQuery
          .of(context)
          .size
          .width,

      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _selectedImages.isEmpty
          ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text("교통 상황이 잘 보이는\n사진을 선택해주세요",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5)),
        ],
      )
          : Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_selectedImages[0], fit: BoxFit.cover),
          Positioned(
            bottom: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("대표 이미지",
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: Colors.grey.withOpacity(0.2), style: BorderStyle.solid),
      ),
      child: const Center(
        child: Text(
          "위의 아이콘을 눌러 사진을 추가하세요",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }


  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _selectedImages.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            // 이미지 컨테이너
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      spreadRadius: 1
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                  _selectedImages[index],
                  fit: BoxFit.cover
              ),
            ),


            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}