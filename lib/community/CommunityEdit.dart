import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'Location.dart' as loc;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../headandputter/putter.dart';
import 'place_result.dart';
import 'community_editor_widgets.dart'; // MiniQuillToolbar 같은거 네가 빼둔 파일
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'place_geo_utils.dart' as geo;

class CommunityEdit extends StatefulWidget {
  final String docId;
  const CommunityEdit({super.key, required this.docId});

  @override
  State<CommunityEdit> createState() => _CommunityEditState();
}

class _CommunityEditState extends State<CommunityEdit> {
  GoogleMapController? _mapCtrl;
  LatLng? _placePos; // 현재 핀 위치
  double _mapZoom = 17; // 현재 줌 기억

  late QuillController _editorController;
  final TextEditingController _title = TextEditingController();
  bool _loading = true;

  // ✅ 새글과 동일하게
  final List<String> categories = ["사건/이슈", "수다", "패션"];
  String selectedCategory = "사건/이슈";

  PlaceResult? selectedPlace;

  // ✅ 날씨/대기(DB 값 그대로 표시)
  int? _weatherCode;
  double? _temp;
  double? _wind;
  int? _rainChance;
  double? _pm10;
  double? _pm25;

  // 커서 위치 기억(새글에서 쓰던 로직)
  int _lastValidOffset = 0;

  bool _weatherLoading = false;
  bool _dirty = false; // 변경 여부
  late String _originTitle;
  late String _originCategory;
  late String _originDocJson;
  PlaceResult? _originPlace;

  // Dropdown (새글과 동일)
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  final ImagePicker _picker = ImagePicker();

  bool _isUrl(String s) => s.startsWith('http://') || s.startsWith('https://');

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  @override
  void initState() {
    super.initState();

    _editorController = QuillController(
      document: Document.fromJson(const [
        {'insert': '\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _editorController.addListener(() {
      final o = _editorController.selection.baseOffset;
      if (o >= 0) _lastValidOffset = o;
    });

    _loadExistingPost();
  }

  Future<void> _moveCamera(LatLng target, {double? zoom}) async {
    final z = zoom ?? _mapZoom;
    _mapZoom = z;
    await _mapCtrl?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: z),
      ),
    );
  }

  String _t(String? s) => (s ?? '').trim().replaceFirst(RegExp(r'^KR\s+'), '');

  String? _bestDisplayNameFromPlacemark(Placemark pm) {
    final subLocality = _t(pm.subLocality); // 동/읍/면
    final subAdmin = _t(pm.subAdministrativeArea); // 구/군
    final locality = _t(pm.locality); // 시
    final admin = _t(pm.administrativeArea); // 도/광역시

    if (subLocality.isNotEmpty) return subLocality;

    final candidates = <String>[
      _t(pm.name),
      _t(pm.thoroughfare),
      _t(pm.subAdministrativeArea),
      _t(pm.locality),
      _t(pm.administrativeArea),
    ].where((e) => e.isNotEmpty).toList();

    final tokens = <String>{};
    for (final c in candidates) {
      for (final t in c.split(RegExp(r'\s+'))) {
        final tt = t.trim();
        if (tt.isNotEmpty) tokens.add(tt);
      }
    }

    for (final t in tokens) {
      if (RegExp(r'(동|읍|면)$').hasMatch(t)) return t;
    }

    if (subAdmin.isNotEmpty) return subAdmin;
    for (final t in tokens) {
      if (RegExp(r'(구|군)$').hasMatch(t)) return t;
    }

    if (locality.isNotEmpty) return locality;

    if (admin.isNotEmpty) {
      final cleaned = admin
          .replaceAll('특별자치시', '')
          .replaceAll('특별자치도', '')
          .replaceAll('특별시', '')
          .replaceAll('광역시', '')
          .replaceAll('자치시', '')
          .replaceAll('자치도', '')
          .replaceAll('도', '')
          .trim();
      return cleaned.isNotEmpty ? cleaned : admin;
    }

    return null;
  }

  String? _buildAddressFromPlacemark(Placemark pm) {
    final parts = <String>[
      _t(pm.administrativeArea),
      _t(pm.locality),
      _t(pm.subAdministrativeArea),
      _t(pm.subLocality),
      _t(pm.thoroughfare),
    ].where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  int _rankLabel(String? label) {
    if (label == null || label.trim().isEmpty) return 0;
    final v = label.trim();
    if (RegExp(r'(동|읍|면)$').hasMatch(v)) return 3;
    if (RegExp(r'(구|군)$').hasMatch(v)) return 2;
    return 1;
  }

  Future<Map<String, String?>?> _reverseGeocodeFull(LatLng p) async {
    try {
      final pms = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (pms.isEmpty) return null;

      Placemark? bestPm;
      String? bestName;
      int bestRank = -1;

      for (final pm in pms) {
        final name = _bestDisplayNameFromPlacemark(pm);
        final r = _rankLabel(name);
        if (r > bestRank) {
          bestRank = r;
          bestName = name;
          bestPm = pm;
          if (bestRank == 3) break;
        }
      }

      final address = _buildAddressFromPlacemark(bestPm ?? pms.first);

      return {'address': address, 'name': bestName};
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _title.dispose();
    _editorController.dispose();
    _removeDropdown(notify: false);
    super.dispose();
  }

  // -----------------------
  // ✅ 영상 플레이어 (URL/로컬 둘 다)
  // -----------------------
  Future<void> _openVideoPlayerSheet({
    required String source, // url or local path
    required String title,
  }) async {
    final VideoPlayerController vp = _isUrl(source)
        ? VideoPlayerController.networkUrl(Uri.parse(source))
        : VideoPlayerController.file(File(source));

    try {
      await vp.initialize();
    } catch (_) {
      await vp.dispose();
      return;
    }

    final chewie = ChewieController(
      videoPlayerController: vp,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowPlaybackSpeedChanging: true,
    );

    if (!mounted) {
      chewie.dispose();
      vp.dispose();
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: vp.value.aspectRatio,
                      child: Chewie(controller: chewie),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    chewie.dispose();
    vp.dispose();
  }

  // -----------------------
  // ✅ 에디터 삽입(새글과 동일)
  // -----------------------
  void _insertImageIntoEditor(String imagePathOrUrl) {
    final sel = _editorController.selection;
    final index = sel.baseOffset >= 0 ? sel.baseOffset : _lastValidOffset;
    final length = (sel.baseOffset >= 0 && sel.extentOffset >= 0)
        ? (sel.extentOffset - sel.baseOffset)
        : 0;

    if (length > 0) _editorController.replaceText(index, length, '', null);

    _editorController.replaceText(
      index,
      0,
      BlockEmbed.image(imagePathOrUrl),
      null,
    );
    _editorController.replaceText(index + 1, 0, '\n', null);

    _editorController.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      ChangeSource.local,
    );
  }

  Future<void> _updatePlacePosition(LatLng pos) async {
    if (selectedPlace == null) return;

    // 1) 좌표 반영(핀 먼저 움직이게)
    setState(() => _placePos = pos);

    // 2) reverse geocode로 새 이름/주소 얻기
    final info = await geo.reverseGeocodeFull(pos);
    final newAddr = info?.address;
    final newName = info?.name;

    // 3) selectedPlace 자체를 교체 (UI의 “부평동” 같은 이름이 여기서 바뀜)
    setState(() {
      selectedPlace = PlaceResult(
        name: (newName != null && newName.trim().isNotEmpty)
            ? newName.trim()
            : selectedPlace!.name,
        address: (newAddr != null && newAddr.trim().isNotEmpty)
            ? newAddr.trim()
            : selectedPlace!.address,
        lat: pos.latitude,
        lng: pos.longitude,
        distanceM: selectedPlace!.distanceM,
      );
    });

    // 4) 날씨/대기 새 좌표 기준으로 다시 불러오기 (지역 라벨도 바뀜)
    await _refreshWeatherAndAirForPlace(selectedPlace!);

    _checkDirty();
  }

  void _insertVideoIntoEditor({
    required String source,
    required String name,
    String? thumb,
  }) {
    final sel = _editorController.selection;
    final index = sel.baseOffset >= 0 ? sel.baseOffset : _lastValidOffset;
    final length = (sel.baseOffset >= 0 && sel.extentOffset >= 0)
        ? (sel.extentOffset - sel.baseOffset)
        : 0;

    if (length > 0) _editorController.replaceText(index, length, '', null);

    // ✅ URL/로컬 둘 다 payload로 통일
    final payload = jsonEncode({
      'url': _isUrl(source) ? source : null,
      'path': !_isUrl(source) ? source : null,
      'thumb': thumb ?? '',
      'name': name,
    });

    _editorController.replaceText(
      index,
      0,
      BlockEmbed.custom(VideoBlockEmbed(payload)),
      null,
    );
    _editorController.replaceText(index + 1, 0, '\n', null);

    _editorController.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      ChangeSource.local,
    );
  }

  Future<String?> _createVideoThumbFile(String videoPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 800, // 적당히
        quality: 75,
      );
      return thumbPath; // null일 수도 있음
    } catch (e) {
      debugPrint('❌ thumb create error: $e');
      return null;
    }
  }

// payload에 들어갈 thumb 값 만들기(로컬이면 로컬경로, url이면 일단 null)
  Future<String?> _buildThumbForVideoSource(String source) async {
    if (_isUrl(source)) return null; // URL 영상은 여기서 생성 안 함(추후 서버 썸네일 or 업로드시 생성)
    return _createVideoThumbFile(source);
  }

  Future<String> _ensureLocalPath(XFile xf) async {
    final dir = await getTemporaryDirectory();
    final origName = (xf.name.isNotEmpty) ? xf.name : 'video.mp4';
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$origName';
    final outPath = p.join(dir.path, safeName);

    await File(outPath).writeAsBytes(await xf.readAsBytes(), flush: true);
    return outPath;
  }

  Future<void> _pickFromGalleryAndInsert() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;
      for (final f in files) {
        _insertImageIntoEditor(f.path); // 로컬 삽입
      }
    } catch (_) {}
  }

  Future<void> _openPlaceSearch() async {
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(builder: (_) => const loc.Location()),
    );

    if (result != null) {
      setState(() {
        selectedPlace = result;
        _placePos = LatLng(result.lat, result.lng);

        // ✅ 일단 이전 글 날씨 값은 지워서 "새 위치 선택했는데 옛날 날씨"가 보이지 않게
        _temp = null;
        _wind = null;
        _rainChance = null;
        _weatherCode = null;
        _pm10 = null;
        _pm25 = null;
      });

      // ✅ 새 위치 기준으로 날씨/대기 다시 가져오기
      await _refreshWeatherAndAirForPlace(result);
      await _moveCamera(LatLng(result.lat, result.lng), zoom: 17);

      _checkDirty();
    }
  }

  Future<void> _pickFromCameraAndInsert() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (file != null) _insertImageIntoEditor(file.path);
    } catch (_) {}
  }

  Future<void> _pickVideoFromGalleryAndInsert() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (!mounted || file == null) return;

    final localPath = await _ensureLocalPath(file);
    final thumbPath = await _buildThumbForVideoSource(localPath);

    _insertVideoIntoEditor(
      source: localPath,
      name: file.name,
      thumb: thumbPath, // ✅ 썸네일 넣기
    );
  }

  Future<void> _pickVideoFromCameraAndInsert() async {
    final file = await _picker.pickVideo(source: ImageSource.camera);
    if (!mounted || file == null) return;

    final localPath = await _ensureLocalPath(file);
    final thumbPath = await _buildThumbForVideoSource(localPath);

    _insertVideoIntoEditor(
      source: localPath,
      name: file.name.isNotEmpty ? file.name : 'camera_video.mp4',
      thumb: thumbPath, // ✅ 썸네일 넣기
    );
  }

  void _checkDirty() {
    final nowDoc = jsonEncode(_editorController.document.toDelta().toJson());

    final changed =
        _title.text != _originTitle ||
        selectedCategory != _originCategory ||
        nowDoc != _originDocJson ||
        !_samePlace(selectedPlace, _originPlace);

    if (changed != _dirty) {
      setState(() => _dirty = changed);
    }
  }

  bool _samePlace(PlaceResult? a, PlaceResult? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.lat == b.lat && a.lng == b.lng;
  }

  Future<void> _loadExistingPost() async {
    _originTitle = _title.text;
    _originCategory = selectedCategory;
    _originDocJson = jsonEncode(_editorController.document.toDelta().toJson());
    _originPlace = selectedPlace;

    _editorController.addListener(_checkDirty);
    _title.addListener(_checkDirty);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('community')
          .doc(widget.docId)
          .get();

      if (!snap.exists) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final data = snap.data() as Map<String, dynamic>;

      // 기본
      _title.text = (data['title'] ?? '').toString();
      selectedCategory = (data['category'] ?? selectedCategory).toString();

      // place
      final placeRaw = data['place'];
      if (placeRaw is Map) {
        final place = Map<String, dynamic>.from(placeRaw);

        selectedPlace = PlaceResult(
          name: (place['name'] ?? '').toString(),
          address: (place['address'] ?? '').toString(),
          lat: _toDouble(place['lat']) ?? 0,
          lng: _toDouble(place['lng']) ?? 0,
          distanceM: _toDouble(place['distanceM']),
        );
      } else {
        selectedPlace = null;
      }

      // weather / air (DB 저장된 값 그대로 표시)
      final weather = data['weather'];
      if (weather is Map) {
        _temp = _toDouble(weather['temp']);
        _wind = _toDouble(weather['wind']);
        _rainChance = _toInt(weather['rainChance']);
        _weatherCode = _toInt(weather['code']);
      } else {
        _temp = null;
        _wind = null;
        _rainChance = null;
        _weatherCode = null;
      }

      final air = data['air'];
      if (air is Map) {
        _pm10 = _toDouble(air['pm10']);
        _pm25 = _toDouble(air['pm25']);
      } else {
        _pm10 = null;
        _pm25 = null;
      }

      // 본문 구성
      final blocks = (data['blocks'] as List?) ?? [];
      final images = ((data['images'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();
      final videos = ((data['videos'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();
      final thumbs = ((data['videoThumbs'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();

      final List<Map<String, dynamic>> ops = [];

      for (final raw in blocks) {
        if (raw is! Map) continue;
        final b = Map<String, dynamic>.from(raw);
        final t = (b['t'] ?? '').toString();

        if (t == 'text') {
          final text = (b['v'] ?? '').toString();
          if (text.isNotEmpty) ops.add({'insert': text});
          continue;
        }

        if (t == 'image') {
          final idx = (b['v'] as num?)?.toInt() ?? -1;
          if (idx >= 0 && idx < images.length) {
            ops.add({
              'insert': {'image': images[idx]},
            });
            ops.add({'insert': '\n'});
          }
          continue;
        }

        if (t == 'video') {
          final idx = (b['v'] as num?)?.toInt() ?? -1;
          if (idx >= 0 && idx < videos.length) {
            final payload = jsonEncode({
              'url': videos[idx],
              'thumb': (idx < thumbs.length) ? thumbs[idx] : '',
              'name': (b['name'] ?? '').toString(),
            });
            ops.add({
              'insert': {'local_video': payload},
            });
            ops.add({'insert': '\n'});
          }
          continue;
        }
      }

      if (ops.isEmpty) ops.add({'insert': '\n'});
      final doc = Document.fromJson(ops);

      if (!mounted) return;
      setState(() {
        _editorController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _editorController.addListener(() {
          final o = _editorController.selection.baseOffset;
          if (o >= 0) _lastValidOffset = o;
        });
        _loading = false;
      });
    } catch (e) {
      debugPrint("❌ _loadExistingPost error: $e");
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('에러: $e')));
    }

    if (!mounted) return;
    if (selectedPlace != null) {
      setState(() {
        _placePos = LatLng(selectedPlace!.lat, selectedPlace!.lng);
      });
    }
  }

  // -----------------------
  // Dropdown (새글과 동일)
  // -----------------------
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

  void _removeDropdown({bool notify = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (notify && mounted) {
      setState(() => _isOpen = false);
    } else {
      _isOpen = false;
    }
  }

  Future<void> _refreshWeatherAndAirForPlace(PlaceResult place) async {
    setState(() => _weatherLoading = true);

    try {
      final lat = place.lat;
      final lng = place.lng;

      // ✅ 날씨(Open-Meteo)
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
            '?latitude=$lat'
            '&longitude=$lng'
            '&current=temperature_2m,weather_code,wind_speed_10m'
            '&hourly=precipitation_probability'
            '&timezone=Asia%2FSeoul',
      );

      final weatherRes = await http.get(weatherUri);
      if (weatherRes.statusCode != 200) {
        throw Exception('weather http ${weatherRes.statusCode}');
      }

      final weatherJson = jsonDecode(weatherRes.body) as Map<String, dynamic>;
      final current = (weatherJson['current'] as Map<String, dynamic>?);

      final temp = (current?['temperature_2m'] as num?)?.toDouble();
      final wind = (current?['wind_speed_10m'] as num?)?.toDouble();
      final code = (current?['weather_code'] as num?)?.toInt();

      int? rainChance;
      final hourly = weatherJson['hourly'] as Map<String, dynamic>?;
      final probs = (hourly?['precipitation_probability'] as List?)?.cast<dynamic>();
      if (probs != null && probs.isNotEmpty) {
        rainChance = (probs.first as num?)?.toInt();
      }

      // ✅ 대기질(Open-Meteo Air Quality)
      final airUri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
            '?latitude=$lat'
            '&longitude=$lng'
            '&hourly=pm10,pm2_5'
            '&timezone=Asia%2FSeoul',
      );

      final airRes = await http.get(airUri);
      double? pm10;
      double? pm25;

      if (airRes.statusCode == 200) {
        final airJson = jsonDecode(airRes.body) as Map<String, dynamic>;
        final ah = airJson['hourly'] as Map<String, dynamic>?;
        final pm10List = (ah?['pm10'] as List?)?.cast<dynamic>();
        final pm25List = (ah?['pm2_5'] as List?)?.cast<dynamic>();

        if (pm10List != null && pm10List.isNotEmpty) {
          pm10 = (pm10List.first as num?)?.toDouble();
        }
        if (pm25List != null && pm25List.isNotEmpty) {
          pm25 = (pm25List.first as num?)?.toDouble();
        }
      }

      if (!mounted) return;
      setState(() {
        _temp = temp;
        _wind = wind;
        _weatherCode = code;
        _rainChance = rainChance;

        _pm10 = pm10;
        _pm25 = pm25;

        _weatherLoading = false;
      });
    } catch (e) {
      // 실패하면 로딩만 끄고 값은 비워둠
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _temp = null;
        _wind = null;
        _weatherCode = null;
        _rainChance = null;
        _pm10 = null;
        _pm25 = null;
      });
      debugPrint('❌ refreshWeather error: $e');
    }
  }

  OverlayEntry _createOverlayEntry() {
    final double dropdownWidth = 400;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 52),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 180,
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

  // -----------------------
  // UI용(날씨아이콘)
  // -----------------------
  IconData _weatherIcon(int? code) {
    if (code == null) return Icons.cloud_outlined;
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code == 1 || code == 2) return Icons.wb_cloudy_outlined;
    if (code == 3) return Icons.cloud_outlined;
    if (code == 45 || code == 48) return Icons.cloud_outlined;
    if (code >= 51 && code <= 67) return Icons.grain;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.umbrella;
    if (code >= 95) return Icons.thunderstorm_outlined;
    return Icons.cloud_outlined;
  }

  Map<String, dynamic> _buildContentForSave() {
    final delta = _editorController.document.toDelta();
    final ops = delta.toJson(); // List<Map>

    final List<Map<String, dynamic>> blocks = [];
    final List<String> images = [];
    final List<String> videos = [];
    final List<String> videoThumbs = [];
    final possibleKeys = ['local_video', 'video', 'custom_video'];
    String? _extractVideoPayload(Map insert) {
      for (final k in possibleKeys) {
        if (insert.containsKey(k)) return insert[k]?.toString();
      }
      return null;
    }

    for (final op in ops) {
      final insert = op['insert'];

      // 텍스트
      if (insert is String) {
        // quill은 '\n'도 들어오니까, 그대로 저장하되 빈 문자열은 스킵 정도만
        if (insert.isNotEmpty) {
          blocks.add({'t': 'text', 'v': insert});
        }
        continue;
      }

      // embed
      if (insert is Map) {
        // 이미지
        if (insert.containsKey('image')) {
          final urlOrPath = insert['image']?.toString() ?? '';
          if (urlOrPath.isNotEmpty) {
            final idx = images.length;
            images.add(urlOrPath);
            blocks.add({'t': 'image', 'v': idx});
          }
          continue;
        }

        // 비디오 (너는 local_video라는 커스텀 키를 쓰고 있었음)
        final payload = _extractVideoPayload(insert);
        if (payload != null && payload.isNotEmpty) {
          final m = jsonDecode(payload) as Map<String, dynamic>;
          final url = (m['url'] ?? '').toString();
          final path = (m['path'] ?? '').toString();
          final src = url.isNotEmpty ? url : path;

          final thumb = (m['thumb'] ?? '').toString();
          final name = (m['name'] ?? '').toString();

          if (src.isNotEmpty) {
            final idx = videos.length;
            videos.add(src);
            videoThumbs.add(thumb);
            blocks.add({'t': 'video', 'v': idx, 'name': name});
          }
        }
      }
    }

    return {
      'blocks': blocks,
      'images': images,
      'videos': videos,
      'videoThumbs': videoThumbs,
    };
  }

  Future<void> _saveEdit() async {
    try {
      final content = _buildContentForSave();

      final placeMap = selectedPlace == null
          ? null
          : {
        'name': selectedPlace!.name,
        'address': selectedPlace!.address,
        'lat': selectedPlace!.lat,
        'lng': selectedPlace!.lng,
        'distanceM': selectedPlace!.distanceM,
      };

      final weatherMap = (_temp == null && _wind == null && _rainChance == null && _weatherCode == null)
          ? null
          : {
        'temp': _temp,
        'wind': _wind,
        'rainChance': _rainChance,
        'code': _weatherCode,
      };

      final airMap = (_pm10 == null && _pm25 == null)
          ? null
          : {
        'pm10': _pm10,
        'pm25': _pm25,
      };

      await FirebaseFirestore.instance
          .collection('community')
          .doc(widget.docId)
          .update({
        'title': _title.text.trim(),
        'category': selectedCategory,
        'updatedAt': FieldValue.serverTimestamp(),

        // ✅ 본문 저장
        'blocks': content['blocks'],
        'images': content['images'],
        'videos': content['videos'],
        'videoThumbs': content['videoThumbs'],

        // ✅ 위치/날씨/대기 저장
        'place': placeMap,
        'weather': weatherMap,
        'air': airMap,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtClient': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 1,
      body: Scaffold(
        appBar: AppBar(
          title: const Text('수정'),
          actions: [
            IconButton(
              icon: Icon(
                Icons.check,
                color: _dirty ? Colors.green : Colors.grey,
              ),
              onPressed: _dirty ? _saveEdit : null,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ 카테고리 (새글과 동일)
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
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: "제목",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ✅ 툴바 (네가 쓰던 커스텀 툴바)
                    MiniQuillToolbar(
                      controller: _editorController,
                      onPickImageGallery: _pickFromGalleryAndInsert,
                      onPickVideoGallery: _pickVideoFromGalleryAndInsert,
                      onPickImageCamera: _pickFromCameraAndInsert,
                      onPickVideoCamera: _pickVideoFromCameraAndInsert,
                    ),
                    const SizedBox(height: 8),

                    // ✅ 에디터 (URL/로컬 둘 다 보이게 Hybrid builders)
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QuillEditor.basic(
                        controller: _editorController,
                        config: QuillEditorConfig(
                          placeholder: '내용을 입력하세요...',
                          embedBuilders: [
                            HybridImageEmbedBuilder(),
                            HybridVideoEmbedBuilder(
                              onPlay: (src, name) => _openVideoPlayerSheet(
                                source: src,
                                title: name,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ✅ 위치 + 지도 + 날씨/대기 (DB 값 그대로)
                    if (selectedPlace != null) ...[
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
                                  onPressed: () {
                                    setState(() {
                                      selectedPlace = null;
                                      _placePos = null;
                                      _temp = null;
                                      _wind = null;
                                      _rainChance = null;
                                      _weatherCode = null;
                                      _pm10 = null;
                                      _pm25 = null;
                                    });
                                    _checkDirty();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Builder(
                              builder: (context){
                                final pos = _placePos ?? LatLng(selectedPlace!.lat, selectedPlace!.lng);
                                return SizedBox(
                                  height: 400,
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(target: pos, zoom: _mapZoom),

                                      onMapCreated: (c) {
                                        _mapCtrl = c;
                                        _moveCamera(pos, zoom: _mapZoom); // 처음 위치로 맞춤
                                      },

                                      // ✅ 사용자가 확대/축소/이동 하면 현재 줌을 저장
                                      onCameraMove: (cam) {
                                        _mapZoom = cam.zoom;
                                      },

                                      // ✅ 지도 탭하면 핀 이동 + 카메라도 그 위치로 이동(줌 유지)
                                      onTap: (p) async {
                                        await _updatePlacePosition(p);
                                        await _moveCamera(p);
                                      },

                                      markers: {
                                        Marker(
                                          markerId: const MarkerId("selected"),
                                          position: pos,
                                          draggable: true,
                                          onDragEnd: (p) async {
                                            await _updatePlacePosition(p);
                                            await _moveCamera(p);
                                          },
                                        ),
                                      },

                                      // ✅ 확대/축소 버튼 켜기 (요구사항)
                                      zoomControlsEnabled: true,

                                      myLocationButtonEnabled: false,
                                      mapToolbarEnabled: false,
                                      liteModeEnabled: false,

                                      // ✅ 스크롤뷰 안에서 지도 제스처 먹게
                                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                                        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 8),

                            if (_weatherLoading)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: LinearProgressIndicator(),
                              )
                            else if (_temp != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                  "${geo.regionLabelFromNameAddress(
                                  name: selectedPlace!.name,
                                    address: selectedPlace!.address,
                                  )} 현재 날씨",
                                style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(_weatherIcon(_weatherCode), size: 18),
                                      const SizedBox(width: 14),
                                      _miniWeather("온도 ${_temp!.round()}°"),
                                      const SizedBox(width: 12),
                                      _miniWeather("강수 ${_rainChance ?? 0}%"),
                                      const SizedBox(width: 12),
                                      _miniWeather(_pm10 == null ? "PM10 -" : "PM10 ${_pm10!.round()}㎍/㎥"),
                                      const SizedBox(width: 12),
                                      _miniWeather(_pm25 == null ? "PM2.5 -" : "PM2.5 ${_pm25!.round()}㎍/㎥"),
                                      const SizedBox(width: 12),
                                      _miniWeather(_wind == null ? "바람 -" : "바람 ${_wind!.toStringAsFixed(1)}m/s"),
                                    ],
                                  ),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  "날씨 정보를 불러오지 못했습니다.",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _openPlaceSearch,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.white,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_location_alt_outlined),
                              SizedBox(width: 8),
                              Text("위치 추가"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _miniWeather(String label) {
    return Text(label, style: const TextStyle(fontSize: 12));
  }
}
