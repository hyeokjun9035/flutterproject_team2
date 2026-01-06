import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../community/CommunityView.dart';
import '../data/nearby_issues_service.dart';

class NearbyIssuesMapPage extends StatefulWidget {
  const NearbyIssuesMapPage({
    super.key,
    required this.myLat,
    required this.myLng,
    required this.posts,
  });

  final double myLat;
  final double myLng;
  final List<NearbyIssuePost> posts;

  @override
  State<NearbyIssuesMapPage> createState() => _NearbyIssuesMapPageState();
}

class _NearbyIssuesMapPageState extends State<NearbyIssuesMapPage> {
  NearbyIssuePost? _selected;
  GoogleMapController? _mapCtrl;

  final _service = NearbyIssuesService();

  double _radiusMeters = 1000; // 기본 1km
  static const _radiusOptionsMeters = <double>[1000, 3000, 5000]; // 1/3/5km

  int _daysBack = 7;
  static const _daysOptions = <int>[3, 7, 30];

  bool _loading = false;
  List<NearbyIssuePost> _posts = [];

  @override
  void initState() {
    super.initState();
    _posts = widget.posts;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final res = await _service.fetchNearbyIssues(
          myLat: widget.myLat,
          myLng: widget.myLng,
          radiusMeters: _radiusMeters.toInt(),
          daysBack: _daysBack,
          limit: 200,
          batchSize: 200,
          maxPages: 6,
      );

      setState(() {
        _posts = res;
        _loading = false;
        if (_selected != null) {
          final stillExists = _posts.any((p) => p.id == _selected!.id);
          if (!stillExists) _selected = null;
        }
      });

      final visible = _posts.where((p) => p.distanceMeters <= _radiusMeters).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToAll(visible));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  double _zoomForRadius(double meters) {
    final km = meters / 1000.0;
    if (km <= 1) return 15.5;
    if (km <= 3) return 14.2;
    if (km <= 5) return 13.7;
    if (km <= 10) return 12.8;
    if (km <= 20) return 11.8;
    return 11.0;
  }

  Future<void> _fitToAll(List<NearbyIssuePost> visiblePosts) async {
    final c = _mapCtrl;
    if (c == null) return;

    final pts = <LatLng>[
      LatLng(widget.myLat, widget.myLng),
      ...visiblePosts.map((p) => LatLng(p.lat, p.lng)),
    ];

    if (pts.length <= 1) {
      // ✅ 내 위치만 있는 경우: bounds 대신 줌으로 처리
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(pts.first, _zoomForRadius(_radiusMeters)),
      );
      return;
    }

    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
  }

  Future<void> _showRadiusInputDialog() async {
    final controller = TextEditingController(
      text: (_radiusMeters / 1000).toStringAsFixed(0),
    );

    final km = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('반경 입력 (km)'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '예: 2.5',
              suffixText: 'km',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim().replaceAll(',', '.');
                final v = double.tryParse(raw);
                Navigator.pop(ctx, v);
              },
              child: const Text('적용'),
            ),
          ],
        );
      },
    );

    if (km == null) return;

    final nextMeters = (km * 1000).clamp(200.0, 50000.0); // ✅ 0.2km~50km 제한(원하면 조절)
    setState(() {
      _radiusMeters = nextMeters;
      // 반경 밖으로 나간 선택은 해제
      if (_selected != null && (_selected!.distanceMeters > _radiusMeters)) {
        _selected = null;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final visible = widget.posts.where((p) => p.distanceMeters <= _radiusMeters).toList();
      _fitToAll(visible);
    });
  }

  @override
  Widget build(BuildContext context) {
    final myPos = LatLng(widget.myLat, widget.myLng);

    final visiblePosts = _posts.where((p) => p.distanceMeters <= _radiusMeters).toList();

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('me'),
        position: myPos,
        infoWindow: const InfoWindow(title: '내 위치'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        onTap: () => setState(() => _selected = null),
      ),
      ...visiblePosts.map((p) => Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.lat, p.lng),
          infoWindow: InfoWindow(title: p.title),
          onTap: () => setState(() => _selected = p),
      )),
    };

    final circles = <Circle>{
      Circle(
        circleId: const CircleId('radius'),
        center: myPos,
        radius: _radiusMeters,
        strokeWidth: 2,
        strokeColor: const Color(0xFF60A5FA).withOpacity(0.75),
        fillColor: const Color(0xFF60A5FA).withOpacity(0.15),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 주변 사건/이슈 지도'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: myPos, zoom: 15),
            markers: markers,
            circles: circles,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            onTap: (_) => setState(() => _selected = null),
            onMapCreated: (c) {
              _mapCtrl = c;
              WidgetsBinding.instance.addPostFrameCallback((_) => _fitToAll(visiblePosts));
            },
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─────────────────────────────
                    // 1) 반경 줄: 반경칩 + 직접입력 + 로딩
                    // ─────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.radar, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '반경 ${(_radiusMeters / 1000).toStringAsFixed(0)}km',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 10),

                        // 반경 칩들(가로 스크롤)
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final m in _radiusOptionsMeters) ...[
                                  ChoiceChip(
                                    label: Text('${(m / 1000).toStringAsFixed(0)}km'),
                                    selected: _radiusMeters == m,
                                    onSelected: (_) {
                                      setState(() {
                                        _radiusMeters = m;
                                        _selected = null;
                                      });
                                      _reload(); // 반경 바뀌면 다시 fetch
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ),

                        IconButton(
                          tooltip: '직접 입력',
                          onPressed: _showRadiusInputDialog,
                          icon: const Icon(Icons.edit, color: Colors.white70),
                        ),

                        // ✅ 로딩 표시: 제일 오른쪽(직접입력 옆)
                        if (_loading) ...[
                          const SizedBox(width: 6),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ─────────────────────────────
                    // 2) 기간 줄: 기간칩 + 표시 건수
                    // ─────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          '기간',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final d in _daysOptions) ...[
                                  ChoiceChip(
                                    label: Text('${d}일'),
                                    selected: _daysBack == d,
                                    onSelected: (_) {
                                      setState(() {
                                        _daysBack = d;
                                        _selected = null;
                                      });
                                      _reload(); // ✅ 기간 바뀌면 다시 fetch
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // ✅ 오른쪽 끝에 표시 건수(지금 화면에 찍히는 마커 수 기준이면 visiblePosts.length)
                        Text(
                          '${visiblePosts.length}건',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _IssuePreviewCard(
                post: _selected!,
                onClose: () => setState(() => _selected = null),
                onOpen: () {
                  final docId = _selected!.id;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Communityview(docId: docId), // ✅ CommunityView 생성자 파라미터명에 맞추기
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _IssuePreviewCard extends StatelessWidget {
  const _IssuePreviewCard({
    required this.post,
    required this.onClose,
    required this.onOpen,
  });

  final NearbyIssuePost post;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final thumb = post.images.isNotEmpty ? post.images.first : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: thumb == null
                      ? Container(
                    color: Colors.white.withOpacity(0.08),
                    child: const Icon(Icons.image, color: Colors.white70),
                  )
                      : Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white.withOpacity(0.08),
                      child: const Icon(Icons.broken_image, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${post.distanceMeters}m · ${post.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '❤️${post.likeCount}  💬${post.commentCount}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
