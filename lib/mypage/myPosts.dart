import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'postCreate.dart';
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
      backgroundColor: const Color(0xFFF8F9FA), // 부드러운 배경색
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
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.locationName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }


  Widget _buildActionButtons(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PostCreate())),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                child: const Icon(Icons.edit_note, color: Colors.blue),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("커뮤니티 글쓰기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("주변의 생생한 정보를 공유해 보세요!", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // 3. 게시글 그리드: 인스타그램 스타일의 정갈함
  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text("내가 작성한 게시글", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Icon(Icons.grid_view_rounded, size: 18, color: Colors.grey),
        ],
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
            List<dynamic> imageUrls = postData['image_urls'] ?? [];
            String displayUrl = imageUrls.isNotEmpty ? imageUrls[0] : 'https://via.placeholder.com/150';

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Detailmypost(
                    imageUrl: displayUrl,
                    postId: posts[index].id,
                    postData: postData,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.grey[200],
                  child: Image.network(
                    displayUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
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