import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'Location.dart' as loc;
import 'place_result.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/dashboard_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../headandputter/putter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Event.dart';
import 'Chatter.dart';
import 'Fashion.dart';

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

Future<String> _uploadFileToStorage({
  required File file,
  required String storagePath, // 예: community/{docId}/images/xxx.jpg
  required String contentType, // 예: image/jpeg, video/mp4
}) async {
  final ref = FirebaseStorage.instance.ref().child(storagePath);

  final metadata = SettableMetadata(contentType: contentType);

  final task = ref.putFile(file, metadata);

  // (선택) 진행률 보고 싶으면 task.snapshotEvents.listen(...)
  final snap = await task.whenComplete(() {});
  final url = await snap.ref.getDownloadURL();
  return url;
}

String _guessImageContentType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _guessVideoContentType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  return 'video/mp4';
}

// ✅✅✅ 여기 추가하면 됨 (클래스 밖)
String? _extractLocalVideoRawFromInsertMap(Map insert) {
  const kType = 'local_video';
  // 케이스 A) {"insert": {"local_video": "..."}}
  if (insert.containsKey(kType)) {
    return insert[kType]?.toString();
  }

  if (insert.containsKey('custom')) {
    final customStr = insert['custom']?.toString();
    if (customStr == null || customStr.isEmpty) return null;

    try {
      final decoded = jsonDecode(customStr);
      if (decoded is Map && decoded.containsKey(kType)) {
        return decoded[kType]?.toString();
      }
    } catch (_) {}
  }

  return null;
}

class _MiniQuillToolbar extends StatelessWidget {
  final QuillController controller;

  final VoidCallback onPickImageGallery;
  final VoidCallback onPickVideoGallery;
  final VoidCallback onPickImageCamera;
  final VoidCallback onPickVideoCamera;

  const _MiniQuillToolbar({
    required this.controller,
    required this.onPickImageGallery,
    required this.onPickVideoGallery,
    required this.onPickImageCamera,
    required this.onPickVideoCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _icon(
            icon: Icons.undo,
            onTap: () {
              if (controller.hasUndo) controller.undo();
            },
          ),
          _icon(
            icon: Icons.redo,
            onTap: () {
              if (controller.hasRedo) controller.redo();
            },
          ),

          _toggleAttr(icon: Icons.format_bold, attr: Attribute.bold),
          _toggleAttr(icon: Icons.format_italic, attr: Attribute.italic),
          _toggleAttr(icon: Icons.format_underline, attr: Attribute.underline),


          _toggleList(icon: Icons.format_list_bulleted, listType: Attribute.ul),

          const Spacer(),

          // ✅ 여기부터 미디어 버튼(툴바 안으로!)
          _icon(icon: Icons.photo_outlined, onTap: onPickImageGallery),
          _icon(icon: Icons.videocam_outlined, onTap: onPickVideoGallery),

          PopupMenuButton<String>(
            tooltip: '카메라',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            onSelected: (v) {
              if (v == 'photo') onPickImageCamera();
              if (v == 'video') onPickVideoCamera();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'photo', child: Text('사진 촬영')),
              PopupMenuItem(value: 'video', child: Text('동영상 촬영')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _icon({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 20,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }

  Widget _toggleAttr({required IconData icon, required Attribute attr}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 20,
      onPressed: () {
        final current = controller.getSelectionStyle().attributes[attr.key];
        controller.formatSelection(
          current == null ? attr : Attribute.clone(attr, null),
        );
      },
      icon: Icon(icon),
    );
  }

  Widget _toggleList({required IconData icon, required Attribute listType}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 20,
      onPressed: () {
        final attrs = controller.getSelectionStyle().attributes;
        final current = attrs[Attribute.list.key];
        controller.formatSelection(
          current == null ? listType : Attribute.clone(Attribute.list, null),
        );
      },
      icon: Icon(icon),
    );
  }
}

class _LocalImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType; // 'image'

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final embed = embedContext.node as Embed;
    final String path = embed.value.data.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('이미지를 불러올 수 없음'),
        ),
      ),
    );
  }
}

class LocalVideoEmbedBuilder extends EmbedBuilder {
  final void Function(String path, String name) onPlay;
  LocalVideoEmbedBuilder({required this.onPlay});
  @override
  String get key => VideoBlockEmbed.kType;

  final Map<String, Future<Uint8List?>> _thumbCache = {};

  Future<Uint8List?> _thumbBytes(String path) {
    return _thumbCache.putIfAbsent(path, () async {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 900,
        quality: 75,
      );
      return bytes;
    });
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final embed = embedContext.node as Embed;
    final raw = embed.value.data.toString();

    String path = raw;
    String name = raw.split('/').last;

    // ✅ JSON이면 path/name 꺼내기
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      path = (m['path'] ?? path).toString();
      name = (m['name'] ?? name).toString();
    } catch (_) {}

    if (path.isEmpty || !File(path).existsSync()) {
      return _fallback(name);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder<Uint8List?>(
          future: _thumbBytes(path),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _loading();
            }
            final bytes = snap.data;
            if (bytes == null) return _fallback(name);

            return GestureDetector(
              onTap: () => onPlay(path, name),

              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 34),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _loading() => const AspectRatio(
    aspectRatio: 16 / 9,
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );

  Widget _fallback(String name) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
    ),
    child: Row(
      children: [
        const Icon(Icons.movie_outlined),
        const SizedBox(width: 8),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

class VideoBlockEmbed extends CustomBlockEmbed {
  static const String kType = 'local_video';

  VideoBlockEmbed(String value) : super(kType, value);

  static VideoBlockEmbed fromNode(Embed node) =>
      VideoBlockEmbed(node.value.data.toString());
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
  int _lastValidOffset = 0;
  late final DashboardService _service;
  late final QuillController _editorController;
  PlaceResult? selectedPlace;
  final List<String> categories = ["사건/이슈", "수다", "패션"];
  String selectedCategory = "사건/이슈";
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _title = TextEditingController();
  final Map<String, int> _imageIndexByLocalPath = {}; // localPath -> images index
  final Map<String, int> _videoIndexByLocalPath = {}; // localPath -> videos index

  void _insertImageIntoEditor(String imagePath) {
    final sel = _editorController.selection;

    final index = sel.baseOffset >= 0 ? sel.baseOffset : _lastValidOffset;
    final length = (sel.baseOffset >= 0 && sel.extentOffset >= 0)
        ? (sel.extentOffset - sel.baseOffset)
        : 0;

    if (length > 0) {
      _editorController.replaceText(index, length, '', null);
    }

    _editorController.replaceText(index, 0, BlockEmbed.image(imagePath), null);
    _editorController.replaceText(index + 1, 0, '\n', null);

    _editorController.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      ChangeSource.local,
    );
  }

  Future<Map<String, dynamic>> _buildBlocksAndUpload({
    required String docId,
  }) async {
    final List<Map<String, dynamic>> blocks = [];
    final List<String> imageUrls = [];
    final List<String> videoUrls = [];
    final List<String> videoThumbUrls = [];

    final deltaJson = _editorController.document.toDelta().toJson();
    final plain = _editorController.document.toPlainText();

    for (final op in deltaJson) {
      final insert = op['insert'];

      // 1) 텍스트
      if (insert is String) {
        if (insert.isNotEmpty) {
          blocks.add({'t': 'text', 'v': insert});
        }
        continue;
      }

      // 2) 임베드(이미지/비디오)
      if (insert is Map) {
        // 2-1) image
        if (insert.containsKey('image')) {
          final localPath = insert['image']?.toString() ?? '';
          if (localPath.isEmpty) continue;

          if (_imageIndexByLocalPath.containsKey(localPath)) {
            blocks.add({'t': 'image', 'v': _imageIndexByLocalPath[localPath]});
            continue;
          }

          final file = File(localPath);
          if (!file.existsSync()) continue;

          final ext = p.extension(localPath).replaceFirst('.', '');
          final safeName =
              '${DateTime.now().millisecondsSinceEpoch}_${p.basename(localPath).isNotEmpty ? p.basename(localPath) : "image.$ext"}';

          final url = await _uploadFileToStorage(
            file: file,
            storagePath: 'community/$docId/images/$safeName',
            contentType: _guessImageContentType(localPath),
          );

          final idx = imageUrls.length;
          imageUrls.add(url);
          _imageIndexByLocalPath[localPath] = idx;

          blocks.add({'t': 'image', 'v': idx});
          continue;
        }

        // 2-2) local_video
        final raw = _extractLocalVideoRawFromInsertMap(insert);
        if (raw != null && raw.isNotEmpty) {
          String localPath = raw;
          String name = p.basename(raw);

          try {
            final m = jsonDecode(raw) as Map<String, dynamic>;
            localPath = (m['path'] ?? localPath).toString();
            name = (m['name'] ?? name).toString();
          } catch (_) {}

          if (localPath.isEmpty) continue;

          if (_videoIndexByLocalPath.containsKey(localPath)) {
            blocks.add({
              't': 'video',
              'v': _videoIndexByLocalPath[localPath],
              'name': name,
            });
            continue;
          }

          final file = File(localPath);
          if (!file.existsSync()) continue;

          final ext = p.extension(localPath).replaceFirst('.', '');
          final safeName =
              '${DateTime.now().millisecondsSinceEpoch}_${name.isNotEmpty ? name : "video.$ext"}';

          final url = await _uploadFileToStorage(
            file: file,
            storagePath: 'community/$docId/videos/$safeName',
            contentType: _guessVideoContentType(localPath),
          );

          // ✅ 썸네일 생성 + 업로드 (비디오에서만!)
          String thumbUrl = '';
          try {
            final thumbBytes = await VideoThumbnail.thumbnailData(
              video: localPath,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 900,
              quality: 75,
            );

            if (thumbBytes != null) {
              final tempDir = await getTemporaryDirectory();
              final thumbPath = p.join(
                tempDir.path,
                '${DateTime.now().millisecondsSinceEpoch}_thumb.jpg',
              );
              final thumbFile = File(thumbPath);
              await thumbFile.writeAsBytes(thumbBytes, flush: true);

              thumbUrl = await _uploadFileToStorage(
                file: thumbFile,
                storagePath:
                'community/$docId/video_thumbs/${p.basenameWithoutExtension(safeName)}.jpg',
                contentType: 'image/jpeg',
              );
            }
          } catch (_) {}

          final idx = videoUrls.length;
          videoUrls.add(url);
          videoThumbUrls.add(thumbUrl); // idx랑 항상 같은 순서로 맞춤
          _videoIndexByLocalPath[localPath] = idx;

          blocks.add({'t': 'video', 'v': idx, 'name': name});
          continue;
        }
      }
    }

    return {
      'blocks': blocks,
      'images': imageUrls,
      'videos': videoUrls,
      'videoThumbs': videoThumbUrls,
      'plain': plain.trim(),
    };
  }

  Future<void> _openVideoPlayerSheet({
    required String path,
    required String title,
  }) async {
    if (!File(path).existsSync()) return;

    final vp = VideoPlayerController.file(File(path));
    await vp.initialize();

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
                // 상단바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

    // 닫히면 정리
    chewie.dispose();
    vp.dispose();
  }

  void _insertVideoIntoEditor({required String videoPath, required String originalName}) {
    final sel = _editorController.selection;
    final index = sel.baseOffset >= 0 ? sel.baseOffset : _lastValidOffset;
    final length = (sel.baseOffset >= 0 && sel.extentOffset >= 0)
        ? (sel.extentOffset - sel.baseOffset)
        : 0;

    if (length > 0) _editorController.replaceText(index, length, '', null);

    final payload = jsonEncode({'path': videoPath, 'name': originalName});

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

  Future<String> _ensureLocalPath(XFile xf) async {
    final dir = await getTemporaryDirectory(); // ✅ 앱 캐시 폴더
    final origName = (xf.name.isNotEmpty) ? xf.name : 'video.mp4';
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$origName';
    final outPath = p.join(dir.path, safeName);

    await File(outPath).writeAsBytes(await xf.readAsBytes(), flush: true);
    return outPath;
  }
  //함수 추가
  Future<void> _ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      // 로그인이 안 되어 있다면 익명 로그인을 시도합니다.
      await auth.signInAnonymously();
    }
  }

  Future<void> _addCommunity() async {
    final user = FirebaseAuth.instance.currentUser;


    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final uid = user.uid;
    await _ensureSignedIn();

    debugPrint('[DELTA] ${jsonEncode(_editorController.document.toDelta().toJson())}');

    final categoryAtSubmit = selectedCategory;
    final title = _title.text.trim();
    final plain = _editorController.document.toPlainText().trim();

    if (title.isEmpty || plain.isEmpty) {
      print("제목 또는 내용 입력");
      return;
    }

    final fs = FirebaseFirestore.instance;
    final userDoc = await fs.collection('users').doc(user.uid).get();
    final String nickname = userDoc.data()?['nickname'] ?? "익명 제보자";

    final docRef = fs.collection("community").doc(); // docId 미리 생성
    final docId = docRef.id;

// users/{uid} 에서 프로필 가져오기
    final userSnap = await fs.collection('users').doc(uid).get();
    if (!userSnap.exists) {
      // 프로필이 아직 저장 안 됐거나 삭제된 상태
      // 여기서 막거나, 기본값으로 생성하거나 선택
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 정보를 찾을 수 없어요. 다시 로그인/회원가입을 확인해주세요.')),
      );
      return;
    }
    final userData = userSnap.data() ?? {};

    final String myNickName = (userData['nickName'] ?? userData['nickname'] ?? '익명').toString();
// 네 users 문서에 nickname/name 이 있으니 그걸 우선 사용
    final author = {
      'uid': uid,

      'nickName': myNickName,
      'name': (userData['name'] ?? '').toString(),
      'email': (userData['email'] ?? '').toString(),
      'profile_image_url': (userData['profile_image_url'] ?? '').toString(),
    };

    // ✅ delta를 읽어서 “저장용 blocks + images + videos” 생성(업로드 포함)
    final built  = await _buildBlocksAndUpload(docId: docId);
    final blocks = built['blocks'] as List<dynamic>;
    final imageUrls = built['images'] as List<String>;
    final videoUrls = built['videos'] as List<String>;
    final videoThumbUrls = built['videoThumbs'] as List<String>;
    final plainForSearch = (built['plain'] as String?) ?? '';

    // ✅ Firestore 저장
    await docRef.set({
      'title': title,
      'category': categoryAtSubmit,
      'user_nickname': myNickName,
      'createdBy': uid,
      'author': author,

      // ✅ 핵심: 순서 정보
      'blocks': blocks,

      // ✅ 미디어 URL 따로
      'images': imageUrls,
      'videos': videoUrls,
      'videoThumbs': videoThumbUrls,

      // (선택) 검색/리스트 요약용
      'plain': plainForSearch,

      'place': selectedPlace == null
          ? null
          : {
        'name': selectedPlace!.name,
        'address': selectedPlace!.address,
        'lat': selectedPlace!.lat,
        'lng': selectedPlace!.lng,
        'distanceM': selectedPlace!.distanceM,
      },

      'weather': {
        'temp': _temp,
        'wind': _wind,
        'rainChance': _rainChance,
        'code': _weatherCode,
      },
      'air': {'pm10': _pm10, 'pm25': _pm25},

      'viewCount': 0,

      'commentCount': 0,

      'likeCount': 0,

      'createdAt': FieldValue.serverTimestamp(),
      'createdAtClient': DateTime.now().millisecondsSinceEpoch,
    });

    // 초기화
    _title.clear();
    _editorController.clear();
    setState(() {
      selectedCategory = categories.first;
      selectedPlace = null;
      _temp = null;
      _wind = null;
      _rainChance = null;
      _weatherCode = null;
      _pm10 = null;
      _pm25 = null;

      // ✅ 캐시도 초기화(다음 글에 영향 없게)
      _imageIndexByLocalPath.clear();
      _videoIndexByLocalPath.clear();
    });

    if (!mounted) return;

    // ✅ 카테고리별 이동(네가 원한 동작)
    Widget target;
    switch (categoryAtSubmit) {
      case "사건/이슈":
        target = const Event();
        break;
      case "수다":
        target = const Chatter();
        break;
      case "패션":
        target = const Fashion();
        break;
      default:
        target = const Event();
    }


    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromGalleryAndInsert() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;

      for (final f in files) {
        _insertImageIntoEditor(f.path);
      }
    } catch (_) {}
  }


  Future<void> _pickFromCameraAndInsert() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;

      if (file != null) {
        _insertImageIntoEditor(file.path);
      }
    } catch (_) {}
  }

  Future<void> _pickVideoFromGalleryAndInsert() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (!mounted || file == null) return;

    final localPath = await _ensureLocalPath(file);

    _insertVideoIntoEditor(
      videoPath: localPath,
      originalName: file.name, // ✅ Accident1.mp4
    );
  }

  Future<void> _pickVideoFromCameraAndInsert() async {
    final file = await _picker.pickVideo(source: ImageSource.camera);
    if (!mounted || file == null) return;

    final localPath = await _ensureLocalPath(file);

    _insertVideoIntoEditor(
      videoPath: localPath,
      originalName: file.name.isNotEmpty ? file.name : 'camera_video.mp4',
    );
  }

  @override
  void initState() {
    super.initState();
    _service = DashboardService(region: 'asia-northeast3');
    _editorController = QuillController.basic();

    _editorController.addListener(() {
      final o = _editorController.selection.baseOffset;
      if (o >= 0) _lastValidOffset = o;
    });
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
      final district = _t(p.locality).isNotEmpty
          ? _t(p.locality)
          : _t(p.subAdministrativeArea);
      final addr = [admin, district].where((e) => e.isNotEmpty).join(' ');
      if (addr.isNotEmpty) return addr;
    }

    return '';
  }

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

  void _removeDropdown({bool notify = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (notify && mounted) {
      setState(() => _isOpen = false);
    } else {
      _isOpen = false;
    }
  }

  OverlayEntry _createOverlayEntry() {
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
    _scrollController.dispose();
    _title.dispose();
    _editorController.dispose();
    _removeDropdown(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 1,
      body: Scaffold(
        appBar: AppBar(title: const Text("새 게시물")),
        body: SingleChildScrollView(
          controller: _scrollController,
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
                controller: _title,
                decoration: const InputDecoration(
                  labelText: "제목",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ 내가 원하는 버튼만 "한 줄" 커스텀 툴바
                  _MiniQuillToolbar(
                    controller: _editorController,
                    onPickImageGallery: _pickFromGalleryAndInsert,
                    onPickVideoGallery: _pickVideoFromGalleryAndInsert,
                    onPickImageCamera: _pickFromCameraAndInsert,
                    onPickVideoCamera: _pickVideoFromCameraAndInsert,
                  ),

                  const SizedBox(height: 8),

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
                          _LocalImageEmbedBuilder(),
                      LocalVideoEmbedBuilder(
                        onPlay: (path, name) => _openVideoPlayerSheet(path: path, title: name),
                      ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Column(
                children: [
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
                              child: _GoogleMapPreview(
                                place: selectedPlace!,
                              ), // ✅ 이게 맞음
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (_weatherLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
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
                          MaterialPageRoute(
                            builder: (_) => const loc.Location(),
                          ),
                        );

                        if (result != null) {
                          setState(() => selectedPlace = result);
                          await _fetchWeatherForPlace(result);
                          await _fetchAirFromTeamDashboard(result);
                          await Future.delayed(
                            const Duration(milliseconds: 200),
                          );
                          if (!mounted) return;
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                    ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addCommunity,
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
            ],
          ),
        ),
      ),
    );
  }
}
