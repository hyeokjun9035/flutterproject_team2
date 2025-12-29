import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'locationAdd.dart';

class LocationSettings extends StatelessWidget {
  const LocationSettings({super.key});

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

            // 🔥 Firestore 데이터 연동 부분
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('favorites') // 즐겨찾기 서브컬렉션
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
                      var data = docs[index].data() as Map<String, dynamic>;
                      return _buildFavoriteCard(data);
                    },
                  );
                },
              ),
            ),

            // 위치 추가 하기 버튼
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

  // 즐겨찾기 카드 UI 빌더
  Widget _buildFavoriteCard(Map<String, dynamic> data) {
    // 주소 문자열 조합 함수 (SI GUN GIL ROADNO 활용)
    String formatAddress(Map<String, dynamic>? loc) {
      if (loc == null) return "주소 정보 없음";
      return "${loc['SI']} ${loc['GUN']} ${loc['GIL']} ${loc['ROADNO']}";
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.2)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: Colors.grey[400],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['title'] ?? "이름 없음", style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.star, color: Colors.amber, size: 20),
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