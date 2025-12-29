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

  // 🔥 구글 지도 검색 모달창 띄우기
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
            child: const Text("완료", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.2)),
              child: Column(
                children: [
                  _buildSearchRow("출발지", _startPoint, () => _openGoogleMapSearch(true)),
                  const Divider(height: 1, color: Colors.black, thickness: 1.2),
                  _buildSearchRow("도착지", _endPoint, () => _openGoogleMapSearch(false)),
                  const Divider(height: 1, color: Colors.black, thickness: 1.2),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: " 즐겨찾기 별칭",
                      border: InputBorder.none,
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
      title: Text(data == null ? "$label 검색" : "${data['SI']} ${data['GUN']} ${data['GIL']}"),
      trailing: const Icon(Icons.map),
    );
  }

  void _saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _startPoint == null || _endPoint == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').add({
      'title': _titleController.text.trim(),
      'start': _startPoint,
      'end': _endPoint,
      'cdate': FieldValue.serverTimestamp(),
    });
    Navigator.pop(context);
  }
}

// 🔥 구글 지도 검색용 모달 위젯
class _GoogleMapSearchModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;
  const _GoogleMapSearchModal({required this.onLocationSelected});

  @override
  State<_GoogleMapSearchModal> createState() => _GoogleMapSearchModalState();
}

class _GoogleMapSearchModalState extends State<_GoogleMapSearchModal> {
  LatLng _center = const LatLng(37.489, 126.724); // 부평역 기준
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(15),
            child: Text("지도를 움직여 위치를 선택하세요", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _center, zoom: 16),
                  onMapCreated: (c) => _controller = c,
                  onCameraMove: (p) => _center = p.target,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                ),
                const Center(child: Icon(Icons.location_on, color: Colors.red, size: 40)), // 중앙 핀
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // 좌표 -> 주소 변환
              await setLocaleIdentifier("ko_KR");
              List<Placemark> p = await placemarkFromCoordinates(_center.latitude, _center.longitude);
              if (p.isNotEmpty) {
                Placemark place = p[0];
                widget.onLocationSelected({
                  'SI': place.administrativeArea ?? "",
                  'GUN': place.locality ?? "",
                  'GIL': place.thoroughfare ?? "",
                  'ROADNO': int.tryParse(place.subThoroughfare ?? "") ?? 0,
                  'LAT': _center.latitude,
                  'LNG': _center.longitude,
                });
                Navigator.pop(context);
              }
            },
            child: const Text("이 위치로 결정"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}