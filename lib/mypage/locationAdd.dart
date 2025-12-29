import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env 활용

class LocationAdd extends StatefulWidget {
  const LocationAdd({super.key});

  @override
  State<LocationAdd> createState() => _LocationAddState();
}

class _LocationAddState extends State<LocationAdd> {
  final TextEditingController _titleController = TextEditingController();
  Map<String, dynamic>? _startPoint;
  Map<String, dynamic>? _endPoint;

  // 구글 지도 검색 모달창 띄우기
  void _openGoogleMapSearch(bool isStart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoogleMapSearchModal(
        onLocationSelected: (data) {
          setState(() {
            if (isStart) _startPoint = data;
            else _endPoint = data;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("위치 추가", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveToFirebase,
            child: const Text("완료", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, width: 1.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildSearchRow("출발지", _startPoint, () => _openGoogleMapSearch(true)),
                  const Divider(height: 1, color: Colors.grey, thickness: 0.5),
                  _buildSearchRow("도착지", _endPoint, () => _openGoogleMapSearch(false)),
                  const Divider(height: 1, color: Colors.grey, thickness: 0.5),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: " 즐겨찾기 별칭 (예: 집, 회사)",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(15),
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

  Widget _buildSearchRow(String label, Map<String, dynamic>? data, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(label == "출발지" ? Icons.circle_outlined : Icons.location_on, color: Colors.blue),
      title: Text(
        data == null ? "$label 검색" : "${data['SI']} ${data['GUN']} ${data['GIL']}",
        style: TextStyle(color: data == null ? Colors.grey : Colors.black),
      ),
      trailing: const Icon(Icons.search),
    );
  }

  void _saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _startPoint == null || _endPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("위치와 별칭을 확인해주세요.")));
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').add({
      'title': _titleController.text.trim().isEmpty ? "미지정" : _titleController.text.trim(),
      'start': _startPoint,
      'end': _endPoint,
      'cdate': FieldValue.serverTimestamp(),
    });
    Navigator.pop(context);
  }
}

// 🔥 검색 기능이 포함된 구글 지도 모달
class _GoogleMapSearchModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;
  const _GoogleMapSearchModal({required this.onLocationSelected});

  @override
  State<_GoogleMapSearchModal> createState() => _GoogleMapSearchModalState();
}

class _GoogleMapSearchModalState extends State<_GoogleMapSearchModal> {
  LatLng _selectedCenter = const LatLng(37.489, 126.724); // 부평역 기준
  GoogleMapController? _controller;
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};

  // 🔍 주소로 검색하여 지도 이동
  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);

        _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));

        setState(() {
          _selectedCenter = target;
          _markers = {
            Marker(
              markerId: const MarkerId("selected"),
              position: target,
            )
          };
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("주소를 찾을 수 없습니다.")));
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
          // 상단 핸들러
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 5),
            width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          // 🔎 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "주소 또는 장소 입력",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear()),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
          ),
          // 🗺️ 지도 영역
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _selectedCenter, zoom: 16),
              onMapCreated: (c) => _controller = c,
              markers: _markers,
              myLocationButtonEnabled: false, // 커스텀 UI를 위해 비활성 권장
              zoomControlsEnabled: false,
              onTap: (pos) { // 검색 외에 직접 클릭으로도 핀 찍기 가능하게 추가
                setState(() {
                  _selectedCenter = pos;
                  _markers = {Marker(markerId: const MarkerId("selected"), position: pos)};
                });
              },
            ),
          ),
          // ✅ 결정 버튼
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await setLocaleIdentifier("ko_KR");
                List<Placemark> p = await placemarkFromCoordinates(_selectedCenter.latitude, _selectedCenter.longitude);
                if (p.isNotEmpty) {
                  Placemark place = p[0];
                  widget.onLocationSelected({
                    'SI': place.administrativeArea ?? "",
                    'GUN': place.locality ?? "",
                    'GIL': place.thoroughfare ?? "",
                    'ROADNO': int.tryParse(place.subThoroughfare ?? "") ?? 0,
                    'LAT': _selectedCenter.latitude,
                    'LNG': _selectedCenter.longitude,
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("이 위치로 설정", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}