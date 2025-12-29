import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'Location.dart' as loc;
import 'place_result.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/dashboard_service.dart';
import '../data/models.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class Communityadd extends StatefulWidget {
  const Communityadd({super.key});

  @override
  State<Communityadd> createState() => _CommunityaddState();
}

class _WeatherItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WeatherItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _GoogleMapPreview extends StatelessWidget {
  final PlaceResult place;
  const _GoogleMapPreview({required this.place});

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(place.lat, place.lng);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: pos, zoom: 15),
      markers: {Marker(markerId: const MarkerId("selected"), position: pos)},
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      liteModeEnabled: true, // 🔥 미리보기 최적화
    );
  }
}

class _CommunityaddState extends State<Communityadd> {
  late final DashboardService _service;
  PlaceResult? selectedPlace;
  final List<String> categories = ["사건/이슈", "수다", "패션"];
  String selectedCategory = "사건/이슈";

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  Future<void> _pickFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 85, // 0~100 (낮추면 용량 절감)
        maxWidth: 1600,
      );
      if (!mounted) return;

      if (files.isNotEmpty) {
        setState(() => _images.addAll(files));
      }
    } catch (_) {}
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;

      if (file != null) {
        setState(() => _images.add(file));
      }
    } catch (_) {}
  }

  void _removeImageAt(int index) {
    setState(() => _images.removeAt(index));
  }

  Widget _thumb(XFile img) {
    return FutureBuilder<Uint8List>(
      future: img.readAsBytes(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Image.memory(
          snap.data!,
          width: 92,
          height: 92,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }


  @override
  void initState() {
    super.initState();
    _service = DashboardService(region: 'asia-northeast3');
  }

  String _regionLabelFromPlace(PlaceResult p) {
    // 1) address가 있으면 그걸로 대충 시/구만 뽑기 (가장 간단)
    final addr = p.address.trim();

    // 예: "대구 중구 동성로..." -> "대구"
    // 예: "부산광역시 해운대구 ..." -> "부산"
    if (addr.isNotEmpty) {
      final first = addr.split(' ').first; // 첫 토큰(대구/부산광역시/서울특별시 등)

      // "OO광역시/특별시/자치시/도" 같은 꼬리를 정리
      var cleaned = first
          .replaceAll('특별시', '')
          .replaceAll('광역시', '')
          .replaceAll('자치시', '')
          .replaceAll('특별자치시', '')
          .replaceAll('특별자치도', '')
          .replaceAll('자치도', '')
          .replaceAll('도', '');

      // 그래도 비면 원본 첫 토큰
      if (cleaned.isEmpty) cleaned = first;

      return cleaned;
    }

    // 2) address가 비면 장소명에서 뽑기(대구역/부평역 -> 대구/부평)
    final name = p.name.trim();
    if (name.isNotEmpty) {
      // "대구역" -> "대구", "부평역" -> "부평"
      return name
          .replaceAll('역', '')
          .replaceAll('시청', '')
          .replaceAll('터미널', '')
          .trim();
    }

    return "현재";
  }

  String _t(String? s) => (s ?? '').trim().replaceFirst(RegExp(r'^KR\s+'), '');

  String pickAirAddr(List<Placemark> pms) {
    final reg = RegExp(
      r'(서울특별시|부산광역시|대구광역시|인천광역시|광주광역시|대전광역시|울산광역시|세종특별자치시|경기도|강원특별자치도|충청북도|충청남도|전북특별자치도|전라남도|경상북도|경상남도|제주특별자치도)\s*'
      r'([가-힣]+구|[가-힣]+시|[가-힣]+군)',
    );

    for (final p in pms) {
      final blob = [
        _t(p.name),
        _t(p.thoroughfare),
        _t(p.subLocality),
        _t(p.locality),
        _t(p.subAdministrativeArea),
        _t(p.administrativeArea),
      ].where((e) => e.isNotEmpty).join(' ');

      final m = reg.firstMatch(blob);
      if (m != null) return '${m.group(1)} ${m.group(2)}';
    }

    for (final p in pms) {
      final admin = _t(p.administrativeArea);
      final district =
      _t(p.locality).isNotEmpty ? _t(p.locality) : _t(p.subAdministrativeArea);
      final addr = [admin, district].where((e) => e.isNotEmpty).join(' ');
      if (addr.isNotEmpty) return addr;
    }

    return '';
  }

  String? _weatherLine; // 화면에 보여줄 한 줄
  bool _weatherLoading = false;
  int? _weatherCode;
  double? _temp;
  double? _wind;
  int? _rainChance;
  double? _pm10;
  double? _pm25;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  Future<void> _fetchWeatherForPlace(PlaceResult place) async {
    setState(() {
      _weatherLoading = true;
      _temp = null;
      _wind = null;
      _rainChance = null;
      _weatherCode = null;
    });

    try {
      final uri = Uri.parse(
        "https://api.open-meteo.com/v1/forecast"
        "?latitude=${place.lat}"
        "&longitude=${place.lng}"
        "&current=temperature_2m,wind_speed_10m,weather_code"
        "&hourly=precipitation_probability"
        "&timezone=auto",
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception("weather http ${res.statusCode}");
      }

      final map = json.decode(res.body) as Map<String, dynamic>;

      final current = map["current"] as Map<String, dynamic>;
      final temp = (current["temperature_2m"] as num).toDouble();
      final wind = (current["wind_speed_10m"] as num).toDouble();
      final code = (current["weather_code"] as num).toInt();

      int? rainChance;
      final hourly = map["hourly"] as Map<String, dynamic>?;
      final probs = hourly?["precipitation_probability"] as List<dynamic>?;
      if (probs != null && probs.isNotEmpty) {
        rainChance = (probs.first as num).round();
      }

      if (!mounted) return;
      setState(() {
        _temp = temp;
        _wind = wind;
        _rainChance = rainChance;
        _weatherCode = code;
        _weatherLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _temp = null;
        _wind = null;
        _rainChance = null;
        _weatherCode = null;
      });
    }
  }

  Future<void> _fetchAirFromTeamDashboard(PlaceResult place) async {
    try {
      final placemarks = await placemarkFromCoordinates(place.lat, place.lng);

      final adminArea = placemarks.isNotEmpty
          ? (placemarks.first.administrativeArea ?? '').trim()
          : '';

      final airAddr = placemarks.isNotEmpty ? pickAirAddr(placemarks) : '';

      final dashboard = await _service.fetchDashboardByLatLon(
        lat: place.lat,
        lon: place.lng,
        locationName: place.name,
        airAddr: airAddr,
        administrativeArea: adminArea,
      );

      if (!mounted) return;
      setState(() {
        _pm10 = dashboard.air.pm10?.toDouble();
        _pm25 = dashboard.air.pm25?.toDouble();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pm10 = null;
        _pm25 = null;
      });
    }
  }

  // 아주 간단한 코드→문구 매핑(필요하면 더 늘리면 됨)
  String _weatherDesc(int code) {
    if (code == 0) return "맑음";
    if (code == 1 || code == 2) return "대체로 맑음";
    if (code == 3) return "흐림";
    if (code == 45 || code == 48) return "안개";
    if (code >= 51 && code <= 67) return "비";
    if (code >= 71 && code <= 77) return "눈";
    if (code >= 80 && code <= 82) return "소나기";
    if (code >= 95) return "뇌우";
    return "알 수 없음";
  }

  IconData _weatherIcon(int? code) {
    if (code == null) return Icons.cloud_outlined;

    if (code == 0) return Icons.wb_sunny_outlined; // 맑음
    if (code == 1 || code == 2) return Icons.wb_cloudy_outlined; // 구름 조금
    if (code == 3) return Icons.cloud_outlined; // 흐림
    if (code == 45 || code == 48) return Icons.foggy; // 안개 (없으면 cloud로 대체)
    if (code >= 51 && code <= 67) return Icons.grain; // 비(이슬비/비)
    if (code >= 71 && code <= 77) return Icons.ac_unit; // 눈
    if (code >= 80 && code <= 82) return Icons.umbrella; // 소나기
    if (code >= 95) return Icons.thunderstorm_outlined; // 뇌우
    return Icons.cloud_outlined;
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox =
        context.findRenderObject() as RenderBox; // scaffold context
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    // 선택박스 위치를 얻기 위해 CompositedTransformTarget로 연결할 거라
    // 여기서는 “너비”만 잡아주면 됨
    final double dropdownWidth = 400; // 필요하면 double.infinity 대신 박스 너비로 맞춰도 됨

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown, // 바깥 누르면 닫힘
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 52), // ✅ 항상 "아래"로 (박스 높이만큼)
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 180, // 많아지면 스크롤
                    minWidth: 200,
                  ),
                  child: Container(
                    width: dropdownWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: categories.map((item) {
                        final bool selected = item == selectedCategory;
                        return ListTile(
                          dense: true,
                          title: Text(item),
                          trailing: selected ? const Icon(Icons.check) : null,
                          onTap: () {
                            setState(() => selectedCategory = item);
                            _removeDropdown();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("새 게시물")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 이 박스 바로 아래로 항상 펼쳐지게 연결
            CompositedTransformTarget(
              link: _layerLink,
              child: InkWell(
                onTap: _toggleDropdown,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Text(
                        selectedCategory,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      Icon(
                        _isOpen
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              decoration: const InputDecoration(
                labelText: "제목",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: TextField(
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: "내용",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 10),

// ✅ 사진 첨부 영역
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('사진 추가'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _pickFromCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('카메라'),
                ),
              ],
            ),

            if (_images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final img = _images[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 92,
                            height: 92,
                            child: _thumb(img),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => _removeImageAt(i),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],

            if (selectedPlace != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedPlace!.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (selectedPlace!.distanceM != null)
                                Text(
                                  "${(selectedPlace!.distanceM! / 1000).toStringAsFixed(1)}km",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            selectedPlace = null;
                            _temp = null;
                            _wind = null;
                            _rainChance = null;
                            _weatherCode = null;
                            _pm10 = null;
                            _pm25 = null;
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _GoogleMapPreview(place: selectedPlace!), // ✅ 이게 맞음
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_weatherLoading)
                      const Center(
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else if (_temp != null) ...[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${_regionLabelFromPlace(selectedPlace!)} 현재 날씨",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(_weatherIcon(_weatherCode), size: 18),
                            const SizedBox(width: 14),

                            _WeatherItem(
                              icon: Icons.thermostat,
                              label: "온도 ${_temp!.round()}°",
                            ),
                            const SizedBox(width: 12),
                            _WeatherItem(
                              icon: Icons.water_drop,
                              label: "강수 ${_rainChance ?? 0}%",
                            ),
                            const SizedBox(width: 12),
                            _WeatherItem(
                              icon: Icons.blur_on,
                              label: _pm10 == null
                                  ? "PM10 -"
                                  : "PM10 ${_pm10!.round()}㎍/㎥",
                            ),
                            _WeatherItem(
                              icon: Icons.blur_on,
                              label: _pm25 == null
                                  ? "PM2.5 -"
                                  : "PM2.5 ${_pm25!.round()}㎍/㎥",
                            ),
                            const SizedBox(width: 12),
                            _WeatherItem(
                              icon: Icons.air,
                              label: "바람 ${_wind!.toStringAsFixed(1)}m/s",
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (selectedPlace == null)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text("위치추가"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await Navigator.push<PlaceResult>(
                    context,
                    MaterialPageRoute(builder: (_) => const loc.Location()),
                  );

                  if (result != null) {
                    setState(() => selectedPlace = result);
                    await _fetchWeatherForPlace(result);
                    await _fetchAirFromTeamDashboard(result);
                  }
                },
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("공유"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
