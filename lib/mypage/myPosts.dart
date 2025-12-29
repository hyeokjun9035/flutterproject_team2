import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'postCreate.dart';
import 'DetailMypost.dart';
import 'weather_service.dart'; // WeatherService 임포트

class MyPosts extends StatelessWidget {
  const MyPosts({super.key});

  @override
  Widget build(BuildContext context) {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    final weatherService = WeatherService(); // 서비스 인스턴스 생성

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
            // 1. 실제 기상청 API 연동 날씨 영역
            _buildRealTimeWeather(weatherService),

            const SizedBox(height: 30),

            // 2. 게시글 작성하러 가기 버튼
            GestureDetector(
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
                        Text("게시글 작성하러 가기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("-현재 교통상황을 공유해보세요", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. 작성한 게시글 영역 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: const [
                    Icon(Icons.circle, size: 8, color: Colors.black),
                    SizedBox(width: 8),
                    Text("작성한 게시글", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 4. Firestore 내 글 목록
            StreamBuilder<QuerySnapshot>(
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
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 기상청 데이터를 가져와서 보여주는 위젯
  Widget _buildRealTimeWeather(WeatherService service) {
    return FutureBuilder<dynamic>(
      future: service.fetchWeather(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text("날씨 정보를 불러올 수 없습니다.");
        }

        final items = snapshot.data as List<dynamic>;

        // 데이터 파싱 (T1H: 기온, REH: 습도, WSD: 풍속, PTY: 강수형태)
        String temp = _getVal(items, 'T1H');
        String humidity = _getVal(items, 'REH');
        String wind = _getVal(items, 'WSD');
        String pty = _getVal(items, 'PTY');

        return Column(
          children: [
            const SizedBox(height: 10),
            // 강수 형태에 따른 아이콘 변경
            Icon(
              _getWeatherIcon(pty),
              size: 80,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 10),
            Text("온도 : $temp°C", style: const TextStyle(fontSize: 15)),
            const Text("미세먼지 : - (준비중)", style: TextStyle(fontSize: 15, color: Colors.grey)), // 기상청 API는 미세먼지 미제공
            Text("습도 : $humidity%", style: const TextStyle(fontSize: 15)),
            Text("바람 : $wind m/s", style: const TextStyle(fontSize: 15)),
          ],
        );
      },
    );
  }

  // 리스트에서 특정 카테고리의 값을 찾아주는 헬퍼 함수
  String _getVal(List<dynamic> items, String category) {
    return items.firstWhere((i) => i['category'] == category)['obsrValue'].toString();
  }

  // 강수 형태(PTY) 코드값에 따른 아이콘 반환
  IconData _getWeatherIcon(String pty) {
    switch (pty) {
      case "1": return Icons.umbrella; // 비
      case "2": return Icons.cloudy_snowing; // 비/눈
      case "3": return Icons.ac_unit; // 눈
      case "4": return Icons.flash_on; // 소나기
      default: return Icons.wb_sunny_outlined; // 맑음
    }
  }
}