import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
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
        },
      ),
    );
  }

  Future<void> _fetchWeather(double lat, double lon, String locName) async {
    setState(() => _isWeatherLoading = true);
    try {
      final data = await _dashboardService.fetchDashboardByLatLon(
        lat: lat,
        lon: lon,
        locationName: locName,
        airAddr: locName,
        administrativeArea: locName,
      );
      setState(() {
        _weatherData = data;
      });
    } catch (e) {
      debugPrint("날씨 가져오기 실패: $e");
    } finally {
      setState(() => _isWeatherLoading = false);
    }
  }

  Future<void> _savePost() async {
    if (_selectedBoard == null || _contentController.text.trim().isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("모든 정보를 입력해주세요!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      List<String> uploadedUrls = [];

      for (var imageFile in widget.images) {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${widget.images.indexOf(imageFile)}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child('post_images').child(fileName);
        await storageRef.putFile(imageFile);
        String downloadUrl = await storageRef.getDownloadURL();
        uploadedUrls.add(downloadUrl);
      }

      await FirebaseFirestore.instance.collection('community').add({
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
        } : null, // 게시글 저장 시 날씨 정보도 함께 저장
        'cdate': FieldValue.serverTimestamp(),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("뒤로", style: TextStyle(color: Colors.black, fontSize: 16)),
        ),
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton(
            onPressed: _savePost,
            child: const Text("완료", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 100,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                    child: widget.images.isNotEmpty
                        ? Image.file(widget.images[0], fit: BoxFit.cover)
                        : const Center(child: Text("이미지 없음")),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _isWeatherLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text("현재 날씨", style: TextStyle(fontWeight: FontWeight.bold)),
                        Icon(
                            _getWeatherIcon(_weatherData?.now.pty, _weatherData?.now.sky),
                            size: 30,
                            color: Colors.blueAccent
                        ),
                        Text(
                            "온도 : ${_weatherData?.now.temp ?? '-'}도, 미세먼지: ${_weatherData?.air.gradeText ?? '-'}",
                            style: const TextStyle(fontSize: 10)
                        ),
                        Text(
                            "습도:${_weatherData?.now.humidity?.toInt() ?? '-'}% 바람: ${_weatherData?.now.wind ?? '-'} m/s",
                            style: const TextStyle(fontSize: 10)
                        ),
                        const Text("자동으로 입력됩니다.", style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.2)),
                child: Column(
                  children: [
                    _buildBoardDropdown(),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),
                    InkWell(
                      onTap: _openGoogleMapSearch,
                      child: _buildFieldContent(
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 20, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedLocation == null
                                    ? "위치를 검색하거나 지도를 클릭하세요"
                                    : "${_selectedLocation!['SI']} ${_selectedLocation!['GUN']} ${_selectedLocation!['GIL']}",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _selectedLocation == null ? Colors.grey : Colors.black,
                                    fontWeight: _selectedLocation == null ? FontWeight.normal : FontWeight.bold
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),
                    _buildFieldContent(
                      child: Text(
                        _weatherData == null
                            ? "위치를 선택하면 날씨가 입력됩니다."
                            : "현재 날씨: ${_weatherData!.now.temp}°C, 미세먼지: ${_weatherData!.air.gradeText}, 바람: ${_weatherData!.now.wind}m/s",
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black, thickness: 1.2),
                    Container(
                      height: 150,
                      padding: const EdgeInsets.all(15),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        decoration: const InputDecoration(
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

  Widget _buildBoardDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBoard,
          hint: const Row(
            children: [
              Icon(Icons.bookmark_border, size: 20, color: Colors.black),
              SizedBox(width: 10),
              Text("올라갈 게시판을 선택해주세요.", style: TextStyle(fontSize: 14)),
            ],
          ),
          isExpanded: true,
          items: _boardList
              .map((String b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: (v) => setState(() => _selectedBoard = v),
        ),
      ),
    );
  }
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

  Widget _buildFieldContent({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: child,
    );
  }
}

// 🔥 구글 지도 검색 및 선택 모달
class _GoogleMapSearchModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;
  const _GoogleMapSearchModal({required this.onLocationSelected});

  @override
  State<_GoogleMapSearchModal> createState() => _GoogleMapSearchModalState();
}

class _GoogleMapSearchModalState extends State<_GoogleMapSearchModal> {
  LatLng _currentCenter = const LatLng(37.489, 126.724); // 부평역
  GoogleMapController? _controller;
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};

  void _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        setState(() {
          _currentCenter = target;
          _markers = {Marker(markerId: const MarkerId("selected"), position: target)};
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("검색 결과를 찾을 수 없습니다.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "주소 검색",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentCenter, zoom: 16),
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
              ),
              onPressed: () async {
                await setLocaleIdentifier("ko_KR");
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
                  Navigator.pop(context);
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