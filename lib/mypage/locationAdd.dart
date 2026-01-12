import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class LocationAdd extends StatefulWidget {
  const LocationAdd({super.key});

  @override
  State<LocationAdd> createState() => _LocationAddState();
}

class _LocationAddState extends State<LocationAdd> {
  final TextEditingController _titleController = TextEditingController();
  Map<String, dynamic>? _startPoint;
  Map<String, dynamic>? _endPoint;

  // 🔍 주소 조합 헬퍼 함수 (UI 표시용)
  String _getDisplayAddress(Map<String, dynamic>? data, String defaultText) {
    if (data == null) return defaultText;
    String si = data['SI'] ?? "";
    String gun = data['GUN'] ?? "";
    String gil = data['GIL'] ?? "";
    String roadNo = (data['ROADNO'] != null && data['ROADNO'].toString().isNotEmpty)
        ? " ${data['ROADNO']}"
        : "";

    String fullAddr = "$si $gun $gil$roadNo".trim();
    return fullAddr.isEmpty ? (data['NAME'] ?? "위치 정보 없음") : fullAddr;
  }

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
        _getDisplayAddress(data, "$label 검색"),
        style: TextStyle(color: data == null ? Colors.grey : Colors.black, fontSize: 14),
        overflow: TextOverflow.ellipsis,
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

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').add({
        'title': _titleController.text.trim().isEmpty ? "미지정" : _titleController.text.trim(),
        'start': _startPoint,
        'end': _endPoint,
        'cdate': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("저장 실패: $e")));
    }
  }
}

class _GoogleMapSearchModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;
  const _GoogleMapSearchModal({required this.onLocationSelected});

  @override
  State<_GoogleMapSearchModal> createState() => _GoogleMapSearchModalState();
}

class _GoogleMapSearchModalState extends State<_GoogleMapSearchModal> {
  LatLng _selectedCenter = const LatLng(37.489, 126.724);
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
          _selectedCenter = target;
          _markers = {Marker(markerId: const MarkerId("selected"), position: target)};
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("검색 결과를 찾을 수 없습니다.")));
      }
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
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _searchAddress),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _selectedCenter, zoom: 16),
              onMapCreated: (c) => _controller = c,
              markers: _markers,
              onTap: (pos) {
                setState(() {
                  _selectedCenter = pos;
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
                try {
                  List<Placemark> p = await placemarkFromCoordinates(_selectedCenter.latitude, _selectedCenter.longitude);
                  if (p.isNotEmpty) {
                    Placemark place = p[0];

                    // ✅ 주소 추출 보강 로직
                    String si = place.administrativeArea ?? "";

                    // 군/구 추출 (locality가 없으면 subLocality 확인)
                    String gun = place.locality ?? "";
                    if (gun.isEmpty) gun = place.subAdministrativeArea ?? "";

                    // 동/로/길 추출 (thoroughfare가 없으면 subLocality 확인)
                    String gil = place.thoroughfare ?? "";
                    if (gil.isEmpty) gil = place.subLocality ?? "";

                    widget.onLocationSelected({
                      'SI': si,
                      'GUN': gun,
                      'GIL': gil,
                      'ROADNO': place.subThoroughfare ?? "",
                      'LAT': _selectedCenter.latitude,
                      'LNG': _selectedCenter.longitude,
                      'NAME': place.name ?? "",
                    });
                    if (mounted) Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("주소를 가져올 수 없습니다.")));
                  }
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