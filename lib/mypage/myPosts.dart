import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/community/CommunityAdd.dart'; // Communityadd 클래스가 정의된 파일명으로 확인해주세요
import 'DetailMypost.dart';
import 'package:flutter_project/data/dashboard_service.dart';
import 'package:flutter_project/data/models.dart';

class MyPosts extends StatelessWidget {
  const MyPosts({super.key});

  @override
  Widget build(BuildContext context) {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    final dashboardService = DashboardService(region: 'asia-northeast3');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "내 활동 & 날씨",
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildRealTimeWeather(dashboardService),
            const SizedBox(height: 10),
            _buildActionButtons(context),
            const SizedBox(height: 25),
            _buildPostHeader(),
            _buildPostGrid(myUid),
          ],
        ),
      ),
    );
  }

  // --- 날씨 정보 위젯 ---
  Widget _buildRealTimeWeather(DashboardService service) {
    return FutureBuilder<DashboardData>(
      future: service.fetchDashboardByLatLon(
        lat: 37.5665,
        lon: 126.9780,
        locationName: "서울",
        airAddr: "서울 중구",
        administrativeArea: "서울특별시",
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text("날씨 데이터를 가져올 수 없습니다.");
        }

        final data = snapshot.data!;
        final now = data.now;

        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.locationName, style: const TextStyle(color: Colors.white, fontSize: 18)),
                      Text("${now.temp?.toStringAsFixed(1)}°",
                          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Icon(_getWeatherIcon(now.pty, now.sky), size: 70, color: Colors.white),
                ],
              ),
              const Divider(color: Colors.white24, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _weatherInfoItem(Icons.air, "미세먼지", "${data.air.gradeText}"),
                  _weatherInfoItem(Icons.water_drop, "습도", "${now.humidity?.toInt()}%"),
                  _weatherInfoItem(Icons.wind_power, "바람", "${now.wind}m/s"),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _weatherInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Communityadd())),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.blue),
              const SizedBox(width: 15),
              const Expanded(child: Text("커뮤니티 글쓰기", style: TextStyle(fontWeight: FontWeight.bold))),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("내가 작성한 게시글", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Icon(Icons.grid_view_rounded, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  // --- 핵심 수정된 그리드 부분 ---
  Widget _buildPostGrid(String? myUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community')
          .where('createdBy', isEqualTo: myUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Text("작성된 게시물이 없습니다.", style: TextStyle(color: Colors.grey)),
          );
        }

        final posts = snapshot.data!.docs;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(15),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            var postData = posts[index].data() as Map<String, dynamic>;

            // ✅ 이미지/비디오 썸네일 경로 추출
            List<dynamic> images = postData['images'] ?? [];
            List<dynamic> videoThumbs = postData['videoThumbs'] ?? [];
            String title = postData['title'] ?? '제목 없음';

            String? displayUrl;
            if (images.isNotEmpty) {
              displayUrl = images[0];
            } else if (videoThumbs.isNotEmpty) {
              displayUrl = videoThumbs[0];
            }

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Detailmypost(
                    imageUrl: displayUrl ?? '',
                    postId: posts[index].id,
                    postData: postData,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: const Color(0xFFE9ECEF), // 이미지가 없을 때 배경색
                  child: displayUrl != null
                      ? Image.network(
                    displayUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                  )
                      : Container(
                    // ✅ 이미지가 없는 경우 제목 표시
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getWeatherIcon(int? pty, int? sky) {
    if (pty == null || pty == 0) {
      if (sky == 4) return Icons.cloud;
      if (sky == 3) return Icons.wb_cloudy_rounded;
      return Icons.wb_sunny_rounded;
    }
    switch (pty) {
      case 1: return Icons.umbrella_rounded;
      case 2: return Icons.cloudy_snowing;
      case 3: return Icons.ac_unit_rounded;
      case 4: return Icons.thunderstorm_rounded;
      default: return Icons.wb_sunny_rounded;
    }
  }
}