import 'package:flutter/material.dart';

class Postdelete extends StatelessWidget {
  const Postdelete({super.key});

  // 삭제 확인 팝업창 함수
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("게시글을 삭제 하시겠습니까?", textAlign: TextAlign.center),
          ),
          actionsAlignment: MainAxisAlignment.center, // 버튼 중앙 정렬
          actions: [
            // 취소 버튼
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              child: const Text("취소", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            // 삭제하기 버튼
            ElevatedButton(
              onPressed: () {
                // 여기에 삭제 로직 추가 (예: API 호출)
                Navigator.pop(context); // 팝업 닫기
                Navigator.pop(context); // 수정 페이지 닫기
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              child: const Text("삭제하기", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
          child: const Text("취소", style: TextStyle(color: Colors.black)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 수정 완료 로직
              Navigator.pop(context);
            },
            child: const Text("수정하기", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 이미지 미리보기 (임시 이미지)
            Container(
              width: 120,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Image.network('https://picsum.photos/200', fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),

            // 2. 카테고리 선택 (Dropdown 형식)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: Colors.black54)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: "자유 게시판",
                  items: const [
                    DropdownMenuItem(value: "자유 게시판", child: Text("자유 게시판")),
                  ],
                  onChanged: (value) {},
                ),
              ),
            ),

            // 3. 위치 정보
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.black54),
                  right: BorderSide(color: Colors.black54),
                  bottom: BorderSide(color: Colors.black54),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.location_on_outlined, size: 18),
                  SizedBox(width: 5),
                  Text("부평역"),
                ],
              ),
            ),

            // 4. 본문 입력창
            TextField(
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "내용을 입력하세요",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 5. 삭제하기 버튼
            GestureDetector(
              onTap: () => _showDeleteDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("삭제하기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}