import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../headandputter/putter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'place_result.dart';

class Location extends StatefulWidget {
  const Location({super.key});

  @override
  State<Location> createState() => _LocationState();
}

class _LocationState extends State<Location> {
  late final String kakaoRestKey;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  bool _hasText = false;
  bool _loading = false;

  List<PlaceResult> _results = [];
  List<PlaceResult> _recent = []; // ✅ 추가
  String _lastQuery = ''; // ✅ 추가

  PlaceResult? _selected;
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    kakaoRestKey = dotenv.env['KAKAO_REST_KEY'] ?? '';
    _loadMyLocation();
    _loadRecentHistory(); // ✅ 최근 기록 불러오기
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

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

  Future<void> _loadRecentHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final qs = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('location_history')
        .orderBy('searchedAt', descending: true)
        .limit(10)
        .get();

    final items = qs.docs.map((d) {
      final m = d.data();
      return PlaceResult(
        name: (m['name'] ?? '').toString(),
        address: (m['address'] ?? '').toString(),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
      );
    }).toList();

    if (!mounted) return;
    setState(() => _recent = items);
  }

  Future<void> _saveHistory(PlaceResult p) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('location_history');

    final dup = await col
        .where('lat', isEqualTo: p.lat)
        .where('lng', isEqualTo: p.lng)
        .limit(1)
        .get();

    if (dup.docs.isNotEmpty) {
      await dup.docs.first.reference.update({
        'name': p.name,
        'address': p.address,
        'query': _lastQuery,
        'searchedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await col.add({
        'name': p.name,
        'address': p.address,
        'lat': p.lat,
        'lng': p.lng,
        'query': _lastQuery,
        'searchedAt': FieldValue.serverTimestamp(),
      });
    }

    // ✅ 저장 후 최근 리스트 갱신(선택)
    _loadRecentHistory();
  }

  void _onQueryChanged(String value) {
    setState(() => _hasText = value.isNotEmpty);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      _lastQuery = q;

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
      _selected = null;
    });
  }

  Future<void> _confirm() async {
    if (_selected == null) return;

    double? distM;
    if (_myLat != null && _myLng != null) {
      final meters = Geolocator.distanceBetween(
        _myLat!, _myLng!,
        _selected!.lat, _selected!.lng,
      );
      distM = meters;
    }

    await _saveHistory(_selected!);

    if (!mounted) return;
    Navigator.pop(
      context,
      PlaceResult(
        name: _selected!.name,
        address: _selected!.address,
        lat: _selected!.lat,
        lng: _selected!.lng,
        distanceM: distM,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ showList는 build() 안에서 계산해야 함
    final showList = _hasText ? _results : _recent;

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
                  itemCount: showList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = showList[i];
                    final bool isSelected = _selected != null &&
                        _selected!.lat == p.lat &&
                        _selected!.lng == p.lng;

                    String distText = "";
                    if (_myLat != null && _myLng != null) {
                      final meters = Geolocator.distanceBetween(
                        _myLat!, _myLng!, p.lat, p.lng,
                      );
                      distText = " · ${(meters / 1000).toStringAsFixed(1)}km";
                    }

                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text("${p.address}$distText"),
                      leading: !_hasText ? const Icon(Icons.history) : null,
                      trailing: isSelected ? const Icon(Icons.check) : null,
                      onTap: () => setState(() => _selected = p),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _confirm,
                  child: const Text("위치 추가"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
