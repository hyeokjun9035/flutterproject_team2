import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'postCreate.dart';
import 'DetailMypost.dart';
import 'package:flutter_project/data/dashboard_service.dart'; // 수정된 서비스 임포트
import 'package:flutter_project/data/models.dart'; // DashboardData 모델 임포트

class MyPosts extends StatelessWidget {
  const MyPosts({super.key});

  @override
  Widget build(BuildContext context) {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;


    final dashboardService = DashboardService(region: 'asia-northeast3');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("현재 날씨", style: TextStyle(color: Colors.black, fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            _buildRealTimeWeather(dashboardService),

            const SizedBox(height: 30),
            _buildActionButtons(context),
            const SizedBox(height: 20),
            _buildPostHeader(),
            const SizedBox(height: 10),
            _buildPostGrid(myUid),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PostCreate()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("게시글 작성하러 가기",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("-현재 교통상황을 공유해보세요",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }


  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: const [
            Icon(Icons.circle, size: 8, color: Colors.black),
            SizedBox(width: 8),
            Text("작성한 게시글",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }


  Widget _buildPostGrid(String? myUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community')
          .where('user_id', isEqualTo: myUid)
          .orderBy('cdate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Text("작성한 게시글이 없습니다."),
          );
        }

        final posts = snapshot.data!.docs;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            var postData = posts[index].data() as Map<String, dynamic>;
            List<dynamic> imageUrls = postData['image_urls'] ?? [];
            String displayUrl = imageUrls.isNotEmpty
                ? imageUrls[0]
                : 'https://via.placeholder.com/150';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Detailmypost(
                      imageUrl: displayUrl,
                      postId: posts[index].id,
                      postData: postData,
                    ),
                  ),
                );
              },
              child: Container(
                color: Colors.grey[200],
                child: Image.network(
                  displayUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image),
                ),
              ),
            );
          },
        );
      },
    );
  }

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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text("날씨 정보를 불러올 수 없습니다."),
          );
        }

        final data = snapshot.data!;
        final now = data.now;
        final air = data.air;

        return Column(
          children: [
            const SizedBox(height: 10),

            Icon(
              _getWeatherIcon(now.pty, now.sky),
              size: 80,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 10),
            Text(
              "${data.locationName} : ${now.temp?.toStringAsFixed(1) ?? '-'}°C",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.air, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  "미세먼지: ${air.gradeText} (PM10: ${air.pm10 ?? '-'})",
                  style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text("습도 : ${now.humidity?.toInt() ?? '-'}% | 바람 : ${now.wind ?? '-'} m/s",
                style: const TextStyle(fontSize: 14, color: Colors.grey)),


            if (data.alerts.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(5)),
                child: Text("⚠️ ${data.alerts.first.title}", style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }


  IconData _getWeatherIcon(int? pty, int? sky) {
    if (pty == null || pty == 0) {
      // 강수 없음 -> 하늘 상태 기준
      if (sky == 4) return Icons.cloud; // 흐림
      if (sky == 3) return Icons.wb_cloudy_outlined; // 구름많음
      return Icons.wb_sunny_outlined; // 맑음
    }
    switch (pty) {
      case 1: return Icons.umbrella;
      case 2: return Icons.cloudy_snowing;
      case 3: return Icons.ac_unit;
      case 4: return Icons.thunderstorm;
      default: return Icons.wb_sunny_outlined;
    }
  }

// (이하 기존 UI 헬퍼 함수들은 생략... GridView 로직 포함)
}