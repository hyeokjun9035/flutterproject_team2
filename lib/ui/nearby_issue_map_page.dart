import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  Future<void> _fitToAll() async {
    final c = _mapCtrl;
    if (c == null) return;

    final pts = <LatLng>[
      LatLng(widget.myLat, widget.myLng),
      ...widget.posts.map((p) => LatLng(p.lat, p.lng)),
    ];

    if (pts.isEmpty) return;

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

    // padding: 프리뷰 카드 뜰 공간도 고려
    await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
  }

  @override
  Widget build(BuildContext context) {
    final myPos = LatLng(widget.myLat, widget.myLng);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('me'),
        position: myPos,
        infoWindow: const InfoWindow(title: '내 위치'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        onTap: () => setState(() => _selected = null),
      ),
      ...widget.posts.map((p) {
        return Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.lat, p.lng),
          infoWindow: InfoWindow(title: p.title),
          onTap: () => setState(() => _selected = p),
        );
      }),
    };

    final circles = <Circle>{
      Circle(
        circleId: const CircleId('radius_1km'),
        center: myPos,
        radius: 1000, // ✅ 1km
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
              WidgetsBinding.instance.addPostFrameCallback((_) => _fitToAll());
            },
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IssueDetailStub(postId: _selected!.id),
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

/// 상세 페이지 아직 미구현이라 stub
class IssueDetailStub extends StatelessWidget {
  const IssueDetailStub({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상세(미구현)')),
      body: Center(child: Text('postId = $postId')),
    );
  }
}
