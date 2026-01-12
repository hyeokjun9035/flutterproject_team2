import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 필요한 데이터 모델 및 매니저 임포트
import 'package:flutter_project/notifications/transit_manager.dart';
import 'package:flutter_project/data/favorite_route.dart';
import 'package:flutter_project/data/transit_service.dart';
import 'package:flutter_project/mypage//locationAdd.dart';

class LocationSettings extends StatefulWidget {
  const LocationSettings({super.key});

  @override
  State<LocationSettings> createState() => _LocationSettingsState();
}

class _LocationSettingsState extends State<LocationSettings> {
  // 1. 알림 제어를 위한 매니저 및 상태 변수
  final TransitGuidanceManager _guidanceManager = TransitGuidanceManager();
  final String _tmapApiKey = dotenv.env['TMAP_API_KEY'] ?? "";

  // 현재 어떤 경로가 실행 중인지 ID 저장 (UI 업데이트용)
  String? _runningRouteId;

  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("즐겨찾기 삭제", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("이 장소를 즐겨찾기에서 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('favorites')
                    .doc(docId)
                    .delete();
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("위치 및 실시간 알림",
            style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("나의 즐겨찾기 장소",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('favorites')
                    .orderBy('cdate', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("등록된 장소가 없어요."));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      return _buildFavoriteCard(data, doc.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // 하단 추가 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationAdd())),
                icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
                label: const Text("새 위치 추가하기", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> data, String docId) {
    // FavoriteRoute 객체로 변환
    final route = FavoriteRoute.fromDoc(docId, data);
    final bool isRunning = _runningRouteId == docId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // 카드 상단바
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isRunning ? Colors.blue[50] : const Color(0xFFE3F2FD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bookmark, color: isRunning ? Colors.blue : Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(route.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _showDeleteDialog(context, docId),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                  ),
                ],
              ),
            ),
            // 주소 및 버튼 섹션
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLocationRow(Icons.circle_outlined, "출발", route.start.label, Colors.orangeAccent),
                  const SizedBox(height: 8),
                  _buildLocationRow(Icons.location_on_rounded, "도착", route.end.label, Colors.blueAccent),
                  const SizedBox(height: 16),

                  // 🔥 실시간 알림 제어 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning ? Colors.redAccent : Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        setState(() {
                          if (isRunning) {
                            // 이미 실행 중이면 중지
                            _guidanceManager.stopGuidance();
                            _runningRouteId = null;
                          } else {
                            // 새로운 경로 시작
                            _guidanceManager.startGuidance(
                              favorite: route,
                              apiKey: _tmapApiKey,
                              variant: TransitVariant.fastest,
                            );
                            _runningRouteId = docId;
                          }
                        });
                      },
                      child: Text(
                        isRunning ? "안내 종료" : "실시간 알림 켜기",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text("$label: $address",
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}