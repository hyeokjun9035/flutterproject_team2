import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class NearbyIssuePost {
  NearbyIssuePost({
    required this.id,
    required this.title,
    required this.lat,
    required this.lng,
    required this.address,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    required this.images,
    required this.distanceMeters,
  });

  final String id;
  final String title;
  final double lat;
  final double lng;
  final String address;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final List<String> images;
  final int distanceMeters;
}

class NearbyIssuesService {
  NearbyIssuesService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ✅ 지도용: 반경/기간/limit으로 많이 가져오기 (최근글부터 스캔하며 반경 필터)
  Future<List<NearbyIssuePost>> fetchNearbyIssues({
    required double myLat,
    required double myLng,
    required int radiusMeters,
    int limit = 200,            // 지도에 표시할 최대 개수
    int daysBack = 7,           // 최근 N일
    int batchSize = 200,        // Firestore 한번에 읽을 개수
    int maxPages = 6,           // 최대 몇 번 더 읽을지 (batchSize * maxPages 만큼 스캔)
  }) async {
    final out = <NearbyIssuePost>[];

    final cutoff = DateTime.now().subtract(Duration(days: daysBack));
    final cutoffTs = Timestamp.fromDate(cutoff);

    Query<Map<String, dynamic>> base = _db
        .collection('community')
        .where('category', isEqualTo: '사건/이슈')
    // ✅ createdAt이 Timestamp로 저장돼 있다는 전제 (아래 주의사항 참고)
        .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
        .orderBy('createdAt', descending: true)
        .limit(batchSize);

    DocumentSnapshot<Map<String, dynamic>>? last;
    for (int page = 0; page < maxPages; page++) {
      final q = (last == null) ? base : base.startAfterDocument(last);
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final data = doc.data();

        final place = (data['place'] is Map)
            ? Map<String, dynamic>.from(data['place'])
            : <String, dynamic>{};

        final lat = (place['lat'] is num) ? (place['lat'] as num).toDouble() : double.nan;
        final lng = (place['lng'] is num) ? (place['lng'] as num).toDouble() : double.nan;
        if (lat.isNaN || lng.isNaN) continue;

        final dist = _haversineMeters(myLat, myLng, lat, lng);
        if (dist > radiusMeters) continue;

        final title = (data['title'] ?? '').toString();
        final address = (place['address'] ?? '').toString();

        final likeCount = (data['likeCount'] is num) ? (data['likeCount'] as num).toInt() : 0;
        final commentCount = (data['commentCount'] is num) ? (data['commentCount'] as num).toInt() : 0;

        final createdAt = _parseCreatedAt(data['createdAt']);

        final imagesRaw = data['images'];
        final images = (imagesRaw is List)
            ? imagesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
            : <String>[];

        out.add(
          NearbyIssuePost(
            id: doc.id,
            title: title,
            lat: lat,
            lng: lng,
            address: address,
            likeCount: likeCount,
            commentCount: commentCount,
            createdAt: createdAt,
            images: images,
            distanceMeters: dist.round(),
          ),
        );

        if (out.length >= limit) return out;
      }

      last = snap.docs.last;
    }

    return out;
  }

  Future<List<NearbyIssuePost>> fetchNearbyIssueTop3({
    required double myLat,
    required double myLng,
    int radiusMeters = 1000,
    int maxCandidates = 200,
  }) async {
    // ⚠️ 인덱스 필요할 수 있음: category + createdAt
    final q = _db
        .collection('community')
        .where('category', isEqualTo: '사건/이슈')
        .orderBy('createdAt', descending: true)
        .limit(maxCandidates);

    final snap = await q.get();

    final out = <NearbyIssuePost>[];
    for (final doc in snap.docs) {
      final data = doc.data();

      final place = (data['place'] is Map)
          ? Map<String, dynamic>.from(data['place'])
          : <String, dynamic>{};

      final lat = (place['lat'] is num) ? (place['lat'] as num).toDouble() : double.nan;
      final lng = (place['lng'] is num) ? (place['lng'] as num).toDouble() : double.nan;
      if (lat.isNaN || lng.isNaN) continue;

      final dist = _haversineMeters(myLat, myLng, lat, lng);
      if (dist > radiusMeters) continue;

      final title = (data['title'] ?? '').toString();
      final address = (place['address'] ?? '').toString();

      final likeCount = (data['likeCount'] is num) ? (data['likeCount'] as num).toInt() : 0;
      final commentCount = (data['commentCount'] is num) ? (data['commentCount'] as num).toInt() : 0;

      final createdAt = _parseCreatedAt(data['createdAt']);

      final imagesRaw = data['images'];
      final images = (imagesRaw is List)
          ? imagesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      out.add(
        NearbyIssuePost(
          id: doc.id,
          title: title,
          lat: lat,
          lng: lng,
          address: address,
          likeCount: likeCount,
          commentCount: commentCount,
          createdAt: createdAt,
          images: images,
          distanceMeters: dist.round(),
        ),
      );

      if (out.length >= 3) break; // 최신순이므로 3개 모이면 종료
    }

    return out;
  }

  static DateTime _parseCreatedAt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      // "2025년 12월 31일 PM 6시 3분" 방어 파싱
      final re = RegExp(r'(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일\s*(AM|PM)\s*(\d{1,2})시\s*(\d{1,2})분');
      final m = re.firstMatch(v);
      if (m != null) {
        final y = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final d = int.parse(m.group(3)!);
        final ampm = m.group(4)!;
        var h = int.parse(m.group(5)!);
        final mi = int.parse(m.group(6)!);
        if (ampm == 'PM' && h < 12) h += 12;
        if (ampm == 'AM' && h == 12) h = 0;
        return DateTime(y, mo, d, h, mi);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);


}
