import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'locationAdd.dart';

class LocationSettings extends StatelessWidget {
  const LocationSettings({super.key});

  // 🗑️ 삭제 확인 다이얼로그 함수
  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("즐겨찾기 삭제", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("정말 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 취소
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                // Firestore에서 해당 문서 삭제
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('favorites')
                    .doc(docId)
                    .delete();
              }
              if (context.mounted) Navigator.pop(context); // 닫기
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
            const Text("즐겨 찾기", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('favorites')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("등록된 즐겨찾기가 없습니다."));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 15),
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      // 🔥 여기서 doc.id(문서ID)를 같이 전달합니다.
                      return _buildFavoriteCard(context, data, doc.id);
                    },
                  );
                },
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LocationAdd()),
                  );
                },
                child: const Text("위치 추가 하기",
                    style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 수정된 즐겨찾기 카드 UI 빌더
  Widget _buildFavoriteCard(BuildContext context, Map<String, dynamic> data, String docId) {
    String formatAddress(Map<String, dynamic>? loc) {
      if (loc == null) return "주소 정보 없음";
      // 번지수(ROADNO)가 짤리지 않게 뒤에 붙여줍니다.
      return "${loc['SI']} ${loc['GUN']} ${loc['GIL']} ${loc['ROADNO'] ?? ''}".trim();
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.2)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), // 패딩 소폭 조정
            color: Colors.grey[400],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['title'] ?? "이름 없음", style: const TextStyle(fontWeight: FontWeight.bold)),
                // 🔥 IconButton으로 변경하여 터치 영역을 확보하고 삭제 함수 연결
                IconButton(
                  onPressed: () => _showDeleteDialog(context, docId),
                  icon: const Icon(Icons.star, color: Colors.amber, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black, thickness: 1.2),
          _buildLocationRow("출발지 : ${formatAddress(data['start'])}"),
          const Divider(height: 1, color: Colors.black, thickness: 1.2),
          _buildLocationRow("도착지 : ${formatAddress(data['end'])}"),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}