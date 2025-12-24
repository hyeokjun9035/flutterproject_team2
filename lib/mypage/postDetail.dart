import 'package:flutter/material.dart';

class PostDetail extends StatefulWidget {
  const PostDetail({super.key});

  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  // 게시판 목록 데이터
  final List<String> _boardList = ['자유게시판', '비밀게시판', '공지사항', '필독'];
  String? _selectedBoard; // 선택된 게시판 저장 변수

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("뒤로", style: TextStyle(color: Colors.black, fontSize: 16)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("완료", style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 이미지 및 날씨 요약 영역
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                    ),
                    child: Image.network(
                      'https://picsum.photos/200/150',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        Text("현재 날씨", style: TextStyle(fontWeight: FontWeight.bold)),
                        Icon(Icons.wb_sunny_outlined, size: 30, color: Colors.orange),
                        Text("온도 : 5도, 미세먼지: 30ug/m^3", style: TextStyle(fontSize: 10)),
                        Text("습도:47% 바람: 2.6 m/s", style: TextStyle(fontSize: 10)),
                        Text("자동으로 입력됩니다.", style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              ),
            ),

            // 2. 입력 폼 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: Column(
                  children: [
                    // --- 수정 포인트: 게시판 선택 Dropdown ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBoard,
                          hint: Row(
                            children: const [
                              Icon(Icons.bookmark_border, size: 20, color: Colors.black),
                              SizedBox(width: 10),
                              Text("올라갈 게시판을 선택해주세요.", style: TextStyle(fontSize: 14, color: Colors.black)),
                            ],
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                          items: _boardList.map((String board) {
                            return DropdownMenuItem<String>(
                              value: board,
                              child: Text(board, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedBoard = newValue;
                            });
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),

                    // 위치 입력
                    _buildFieldContent(
                      child: Row(
                        children: const [
                          Icon(Icons.location_on_outlined, size: 20),
                          SizedBox(width: 10),
                          Text("현재 위치 클릭시 현재위치 자동 입력 혹은 검색시", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),

                    // 날씨 정보
                    _buildFieldContent(
                      child: const Text(
                        "현재 날씨: ☀️ 온도: 영상 5도, ☁️ 미세먼지 : 30ug/m^3, 💨 바람: 2.6m/s",
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),

                    // 내용 입력
                    Container(
                      height: 150,
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      child: const TextField(
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: "게시글 내용을 입력해주세요.\nex) 00시 부평역 구간 정체 입니다. ㅠㅠ",
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldContent({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: child,
    );
  }
}