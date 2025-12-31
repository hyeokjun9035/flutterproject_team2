import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart'; // ✅ 날짜 포맷팅을 위해 추가
import 'package:flutter_project/data/dashboard_service.dart';
import 'package:flutter_project/data/models.dart';

class PostDetail extends StatefulWidget {
  final List<File> images;
  const PostDetail({super.key, required this.images});

  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  final List<String> _boardList = ['자유게시판', '비밀게시판'];
  String? _selectedBoard;
  final TextEditingController _contentController = TextEditingController();

  bool _isLoading = false;
  bool _isWeatherLoading = false;
  final _dashboardService = DashboardService(region: 'asia-northeast3');

  Map<String, dynamic>? _selectedLocation;
  DashboardData? _weatherData;

  // 🔍 구글 맵 검색 모달 열기
  void _openGoogleMapSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoogleMapSearchModal(
        onLocationSelected: (data) {
          setState(() {
            _selectedLocation = data;
          });
          _fetchWeather(data['LAT'], data['LNG'], data['SI']);
        },
      ),
    );
  }

  // 🌤 날짜 및 날씨 가져오기
  Future<void> _fetchWeather(double lat, double lon, String locName) async {
    if (!mounted) return;
    setState(() => _isWeatherLoading = true);

    try {
      final data = await _dashboardService.fetchDashboardByLatLon(
        lat: lat, lon: lon, locationName: locName, airAddr: locName, administrativeArea: locName,
      );
      if (mounted) {
        setState(() => _weatherData = data);
      }
    } catch (e) {
      debugPrint("날씨 가져오기 실패: $e");
    } finally {
      if (mounted) setState(() => _isWeatherLoading = false);
    }
  }

  // 💾 게시글 저장 로직
  Future<void> _savePost() async {
    if (_selectedBoard == null || _contentController.text.trim().isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("모든 정보를 입력해주세요!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("로그인이 필요합니다.");


      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String nickname = "익명";
      String realName ="익명";

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        realName = userData['name'] ?? "이름 없음";
        nickname = userData['nickName'] ?? userData['name'] ?? "익명";
      }


      List<String> uploadedUrls = [];
      for (var imageFile in widget.images) {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${widget.images.indexOf(imageFile)}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child('post_images').child(fileName);
        await storageRef.putFile(imageFile);
        String url = await storageRef.getDownloadURL();
        uploadedUrls.add(url);
      }

      // Firestore 저장
      await FirebaseFirestore.instance.collection('community').add({
        'user_name': realName,
        'user_nickname': nickname,
        'board_type': _selectedBoard,
        'title': '교통 제보',
        'content': _contentController.text.trim(),
        'user_id': user?.uid ?? '익명',
        'image_urls': uploadedUrls,
        'location': _selectedLocation,
        'weather': _weatherData != null ? {
          'temp': _weatherData!.now.temp,
          'sky': _weatherData!.now.sky,
          'pty': _weatherData!.now.pty,
          'air_grade': _weatherData!.air.gradeText,
        } : null,
        'cdate': FieldValue.serverTimestamp(), // 정렬용 타임스탬프
        'report_count': 0,
      });

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장에 실패했습니다.")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("제보 상세 내용", style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : TextButton(
            onPressed: _savePost,
            child: const Text("완료", style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    _buildBoardDropdown(),
                    const Divider(height: 1),
                    _buildLocationPicker(),
                    const Divider(height: 1),
                    _buildContentInput(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 요약 카드 (이미지 + 날씨 + 현재시간 표시 가능)
  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 100,
              height: 100,
              child: widget.images.isNotEmpty
                  ? Image.file(widget.images[0], fit: BoxFit.cover)
                  : Container(color: Colors.grey[200]),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _isWeatherLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("현재 지역 날씨", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                _weatherData == null
                    ? const Text("위치를 선택하면\n정보가 표시됩니다.", style: TextStyle(color: Colors.black54, fontSize: 14))
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_getWeatherIcon(_weatherData!.now.pty, _weatherData!.now.sky), color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 5),
                        Text("${_weatherData!.now.temp?.toStringAsFixed(1)}°C", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text("미세먼지: ${_weatherData!.air.gradeText}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    // ✅ 사용자가 요청한 시간 형식 예시 (현재 시간 기준)
                    Text(DateFormat('yyyy년 MM월 dd일 a h:mm', 'ko_KR').format(DateTime.now()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 게시판 선택 드롭다운
  Widget _buildBoardDropdown() {
    return ListTile(
      leading: const Icon(Icons.layers_outlined, color: Colors.blueAccent),
      title: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBoard,
          hint: const Text("게시판 선택", style: TextStyle(fontSize: 15, color: Colors.grey)),
          isExpanded: true,
          items: _boardList.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 15)))).toList(),
          onChanged: (v) => setState(() => _selectedBoard = v),
        ),
      ),
    );
  }

  // 위치 선택 행
  Widget _buildLocationPicker() {
    return ListTile(
      onTap: _openGoogleMapSearch,
      leading: const Icon(Icons.location_on_outlined, color: Colors.redAccent),
      title: Text(
        _selectedLocation == null
            ? "교통 제보 위치 선택"
            : "${_selectedLocation!['SI']} ${_selectedLocation!['GUN']} ${_selectedLocation!['GIL']}",
        style: TextStyle(
            fontSize: 15,
            color: _selectedLocation == null ? Colors.grey : Colors.black,
            fontWeight: _selectedLocation == null ? FontWeight.normal : FontWeight.w600
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
    );
  }

  // 내용 입력창
  Widget _buildContentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: _contentController,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: "정체 구간이나 사고 상황을 알려주세요.\n(예: 부평역 삼거리 공사로 인해 정체 중)",
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // 날씨 아이콘 매칭
  IconData _getWeatherIcon(int? pty, int? sky) {
    if (pty == null || pty == 0) {
      if (sky == 4) return Icons.cloud;
      if (sky == 3) return Icons.wb_cloudy_outlined;
      return Icons.wb_sunny_outlined;
    }
    switch (pty) {
      case 1: return Icons.umbrella;
      case 2: return Icons.cloudy_snowing;
      case 3: return Icons.ac_unit;
      case 4: return Icons.thunderstorm;
      default: return Icons.wb_sunny_outlined;
    }
  }
}

// ✅ 헬퍼 함수: Firestore Timestamp를 요청하신 형식의 문자열로 변환
// (이 함수를 커뮤니티 리스트 화면에서 사용하세요)
String formatTrafficReportDate(Timestamp? timestamp) {
  if (timestamp == null) return "";
  DateTime dt = timestamp.toDate();

  // 포맷: 2025년 12월 31일 AM 11시 35분 33초 UTC+9
  // intl 패키지의 DateFormat 사용
  String formatted = DateFormat('yyyy년 MM월 dd일 a h시 m분 s초', 'ko_KR').format(dt);
  return "$formatted UTC+9";
}

// 🗺 구글 맵 검색 모달 클래스
class _GoogleMapSearchModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;
  const _GoogleMapSearchModal({required this.onLocationSelected});

  @override
  State<_GoogleMapSearchModal> createState() => _GoogleMapSearchModalState();
}

class _GoogleMapSearchModalState extends State<_GoogleMapSearchModal> {
  LatLng _currentCenter = const LatLng(37.489, 126.724);
  GoogleMapController? _controller;
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};

  void _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        if (mounted) {
          setState(() {
            _currentCenter = target;
            _markers = {Marker(markerId: const MarkerId("selected"), position: target)};
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("검색 결과가 없습니다.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "장소 또는 주소 검색",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentCenter, zoom: 15),
              onMapCreated: (c) => _controller = c,
              markers: _markers,
              onTap: (pos) {
                setState(() {
                  _currentCenter = pos;
                  _markers = {Marker(markerId: const MarkerId("selected"), position: pos)};
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                try {
                  List<Placemark> p = await placemarkFromCoordinates(_currentCenter.latitude, _currentCenter.longitude);
                  if (p.isNotEmpty) {
                    Placemark place = p[0];
                    widget.onLocationSelected({
                      'SI': place.administrativeArea ?? "",
                      'GUN': place.locality ?? place.subAdministrativeArea ?? "",
                      'GIL': place.thoroughfare ?? place.subLocality ?? "",
                      'ROADNO': place.subThoroughfare ?? "",
                      'LAT': _currentCenter.latitude,
                      'LNG': _currentCenter.longitude,
                    });
                    if (mounted) Navigator.pop(context);
                  }
                } catch (e) {
                  debugPrint("지오코딩 실패: $e");
                }
              },
              child: const Text("이 위치 선택", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}