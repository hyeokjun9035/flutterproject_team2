import 'package:flutter/material.dart';

class LocationAdd extends StatelessWidget {
  const LocationAdd({super.key});

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
        title: const Text("현재 위치", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("완료", style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 지도 영역 (이미지 참조)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("-검색 결과", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    // 실제 지도 라이브러리 대신 이미지로 대체 표시
                    child: Image.network(
                      'https://tile.openstreetmap.org/17/135/62.png', // 예시 지도 타일 이미지
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),

            // 2. 입력 필드 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: Column(
                  children: [
                    // 출발지 위치
                    _buildInputField(
                      icon: Icons.location_on_outlined,
                      hintText: "출발지 위치(클릭시 현재위치 자동 입력 혹은 검색시)",
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),

                    // 도착지 위치
                    _buildInputField(
                      icon: Icons.outlined_flag,
                      hintText: "도착지 위치(검색시)",
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),

                    // 즐겨찾기 이름
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      child: Row(
                        children: [
                          const Text("즐겨 찾기 이름: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "이름을 작성해주세요.",
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 공통 입력 필드 빌더
  Widget _buildInputField({required IconData icon, required String hintText}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hintText,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}