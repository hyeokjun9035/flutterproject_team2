import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 필요한 데이터 모델 및 매니저 임포트
import 'package:flutter_project/notifications/transit_manager.dart';
import 'package:flutter_project/data/favorite_route.dart';
import 'package:flutter_project/data/transit_service.dart';
import 'package:flutter_project/mypage/locationAdd.dart';
import 'package:flutter_project/data/bus_arrival_service.dart';

class LocationSettings extends StatefulWidget {
  const LocationSettings({super.key});

  @override
  State<LocationSettings> createState() => _LocationSettingsState();
}

class _LocationSettingsState extends State<LocationSettings> {
  final TransitGuidanceManager _guidanceManager = TransitGuidanceManager();
  final String _tmapApiKey = dotenv.env['TMAP_API_KEY'] ?? "";

  // 1. 서비스 및 상태 변수 선언
  late final BusArrivalService _busService;
  String? _runningRouteId;

  // 각 카드별 선택된 모드 저장 (Key: docId, Value: 'time' 또는 'walk')
  final Map<String, String> _selectedMode = {};

  @override
  void initState() {
    super.initState();
    // 서비스 초기화
    _busService = BusArrivalService(
      serviceKey: dotenv.env['BUS_API_KEY'] ?? "",
    );
  }

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
    final route = FavoriteRoute.fromDoc(docId, data);
    final bool isRunning = _runningRouteId == docId;
    final String currentMode = _selectedMode[docId] ?? 'time';

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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLocationRow(Icons.circle_outlined, "출발", route.start.label, Colors.orangeAccent),
                  const SizedBox(height: 8),
                  _buildLocationRow(Icons.location_on_rounded, "도착", route.end.label, Colors.blueAccent),
                  const SizedBox(height: 15),

                  // 🚥 모드 선택 버튼 (최소 시간 vs 최소 도보)
                  Row(
                    children: [
                      _buildModeButton(docId, "최소 시간", 'time', Icons.subway_rounded, Colors.indigo),
                      const SizedBox(width: 8),
                      _buildModeButton(docId, "최소 도보", 'walk', Icons.directions_bus_rounded, Colors.orange),
                    ],
                  ),

                  // 모드에 따른 정보 표시
                  currentMode == 'time'
                      ? _buildSubwayArrivalInfo(route)
                      : _buildBusArrivalInfo(route),

                  const SizedBox(height: 16),
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
                            _guidanceManager.stopGuidance();
                            _runningRouteId = null;
                          } else {
                            _guidanceManager.startGuidance(
                              favorite: route,
                              apiKey: _tmapApiKey,
                              variant: currentMode == 'time' ? TransitVariant.fastest : TransitVariant.minWalk,
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

  Widget _buildModeButton(String docId, String label, String mode, IconData icon, Color color) {
    bool isSelected = (_selectedMode[docId] ?? 'time') == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMode[docId] = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: isSelected ? color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
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

  Widget _buildSubwayArrivalInfo(FavoriteRoute route) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(10)),
      child: const Row(
        children: [
          Icon(Icons.subway, size: 14, color: Colors.indigo),
          SizedBox(width: 6),
          Text("최소 시간 경로 검색 중...", style: TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBusArrivalInfo(FavoriteRoute route) {
    return FutureBuilder<TagoStop?>(
      future: _busService.findNearestStop(lat: route.start.lat, lon: route.start.lng),
      builder: (context, stopSnapshot) {
        if (stopSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text("가까운 정류장 찾는 중...", style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }
        if (!stopSnapshot.hasData || stopSnapshot.data == null) return const SizedBox.shrink();

        final stop = stopSnapshot.data!;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text("인근 정류장: ${stop.name}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
              const Text("정류장 도착 정보를 확인하세요.", style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
        );
      },
    );
  }
}