import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../headandputter/putter.dart';

import 'place_result.dart';

class Location extends StatefulWidget {
  const Location({super.key});

  @override
  State<Location> createState() => _LocationState();
}

class _LocationState extends State<Location> {
  // 🔑 카카오 REST API 키
  late final String kakaoRestKey;

  @override
  void initState() {
    super.initState();
    kakaoRestKey = dotenv.env['KAKAO_REST_KEY'] ?? '';
    _loadMyLocation();
  }

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  bool _hasText = false;
  bool _loading = false;
  List<PlaceResult> _results = [];

  PlaceResult? _selected;
  double? _myLat;
  double? _myLng;

  Future<void> _loadMyLocation() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _myLat = pos.latitude;
      _myLng = pos.longitude;
    });
  }


  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _hasText = value.isNotEmpty);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      if (q.isEmpty) {
        setState(() => _results = []);
        return;
      }
      await _searchKakao(q);
    });
  }

  Future<void> _searchKakao(String query) async {
    if (kakaoRestKey.isEmpty) {
      setState(() {
        _loading = false;
        _results = [];
      });
      // 원하면 여기서 SnackBar로 알려도 됨
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text("KAKAO_REST_KEY가 설정되어 있지 않습니다.")),
      // );
      return;
    }

    setState(() => _loading = true);

    try {
      final uri = Uri.parse(
        "https://dapi.kakao.com/v2/local/search/keyword.json"
            "?query=${Uri.encodeQueryComponent(query)}&size=10",
      );

      final res = await http.get(
        uri,
        headers: {"Authorization": "KakaoAK $kakaoRestKey"},
      );

      if (res.statusCode != 200) {
        setState(() {
          _results = [];
          _loading = false;
        });
        return;
      }

      final jsonMap = json.decode(res.body);
      final docs = jsonMap["documents"] as List;

      final parsed = docs.map((d) {
        final name = d["place_name"];
        final road = d["road_address_name"];
        final addr = (road != null && road.toString().isNotEmpty)
            ? road
            : d["address_name"];

        return PlaceResult(
          name: name,
          address: addr,
          lat: double.parse(d["y"]),
          lng: double.parse(d["x"]),
        );
      }).toList();

      setState(() {
        _results = parsed.cast<PlaceResult>();
        _loading = false;
        _selected = null;
      });
    } catch (_) {
      setState(() {
        _results = [];
        _loading = false;
        _selected = null;
      });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _hasText = false;
      _results = [];
    });
  }

  void _confirm() {
    if (_selected == null) return;

    int? distM;
    if (_myLat != null && _myLng != null) {
      final meters = Geolocator.distanceBetween(
        _myLat!, _myLng!,
        _selected!.lat, _selected!.lng,
      );
      distM = meters.round();
    }

    Navigator.pop(
      context,
      PlaceResult(
        name: _selected!.name,
        address: _selected!.address,
        lat: _selected!.lat,
        lng: _selected!.lng,
        distanceM: distM, // ✅ 거리 포함
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 1,
      body: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: const Text("위치"),
          actions: [
            IconButton(onPressed: _clear, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: "위치 검색",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _hasText
                      ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clear,
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              if (_loading) const LinearProgressIndicator(),

              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    final bool isSelected = _selected != null && _selected!.lat == p.lat && _selected!.lng == p.lng;
                    String distText = "";
                    if (_myLat != null && _myLng != null) {
                      final meters = Geolocator.distanceBetween(
                        _myLat!, _myLng!,
                        p.lat, p.lng,
                      );
                      distText = " · ${(meters / 1000).toStringAsFixed(1)}km";
                    }
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text("${p.address}$distText"),
                      trailing: isSelected ? const Icon(Icons.check) : null,
                      onTap: () => setState(() => _selected = p),
                    );
                  },
                ),
              ),
              SizedBox(height: 12,),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _selected == null ? null : _confirm,
                    child: const Text("위치 추가")
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
