import 'package:flutter/material.dart';

class UserEdit extends StatelessWidget {
  const UserEdit({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 1. 상단 앱바 (취소, 저장 버튼)
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
              // 저장 로직 추가
              Navigator.pop(context);
            },
            child: const Text("저장", style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 2. 프로필 이미지 영역
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage('https://placedog.net/500/500'), // 테스트용 강아지 이미지
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "프로필 수정 하기",
                      style: TextStyle(color: Colors.deepPurple, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 3. 유저 정보 입력 리스트 (둥근 테두리 박스)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildInputField("이름 : ", "홍길동"),
                    const Divider(height: 1, color: Colors.black),
                    _buildInputField("이메일 : ", "TEST@gmail.com"),
                    const Divider(height: 1, color: Colors.black),
                    _buildNicknameField("닉네임: ", "도로위 고라니"),
                    const Divider(height: 1, color: Colors.black),
                    _buildInputField("소개 : ", "안녕하세요!!", isLast: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 일반 입력 필드 (이름, 이메일, 소개)
  Widget _buildInputField(String label, String initialValue, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: initialValue),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // 닉네임 입력 필드 (중복확인 버튼 포함)
  Widget _buildNicknameField(String label, String initialValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: initialValue),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.black54),
              ),
              minimumSize: const Size(80, 30),
            ),
            child: const Text("중복확인", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}