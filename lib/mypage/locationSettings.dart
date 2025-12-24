import 'package:flutter/material.dart';
import 'locationAdd.dart';

class LocationSettings extends StatelessWidget {
  const LocationSettings({super.key});

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
        title: const Text("위치 설정", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 즐겨찾기 탭 레이블
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.grey[300],
              child: const Text("즐겨 찾기", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),

            // 2. 위치 설정 박스 영역
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.2),
              ),
              child: Column(
                children: [
                  // 회색 헤더 (학원 ★)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    color: Colors.grey[600],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("학원", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        Icon(Icons.star, color: Colors.black, size: 20),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black, thickness: 1.2),

                  // 출발지 입력 칸
                  _buildLocationRow("출발지 : 부평역"),
                  const Divider(height: 1, color: Colors.black, thickness: 1.2),

                  // 도착지 입력 칸
                  _buildLocationRow("도착지 : 더조은컴퓨터아카데미학원 인천점"),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // 3. 위치 추가 하기 버튼
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LocationAdd()),
                  );
                },
                child: const Text(
                  "위치 추가 하기",
                  style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 위치 텍스트 행 빌더
  Widget _buildLocationRow(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}