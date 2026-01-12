class FavPoint {
  final double lat;
  final double lng;
  final String si, gun, gil, roadNo;

  FavPoint({
    required this.lat,
    required this.lng,
    required this.si,
    required this.gun,
    required this.gil,
    required this.roadNo,
  });

  String get label =>
      [si, gun, gil, roadNo].where((e) => e.trim().isNotEmpty).join(' ').trim();

  factory FavPoint.fromMap(Map<String, dynamic> m) {
    double readNum(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is num) return v.toDouble();
        final p = double.tryParse('$v');
        if (p != null) return p;
      }
      return 0;
    }

    return FavPoint(
      lat: readNum(['LAT', 'lat']),
      lng: readNum(['LNG', 'lng', 'LON', 'lon']),
      si: (m['SI'] ?? m['si'] ?? '') as String,
      gun: (m['GUN'] ?? m['gun'] ?? '') as String,
      gil: (m['GIL'] ?? m['gil'] ?? '') as String,
      roadNo: (m['ROADNO'] ?? m['roadNo'] ?? m['roadno'] ?? '') as String,
    );
  }
}

class FavoriteRoute {
  final String id;
  final String title;
  final FavPoint start;
  final FavPoint end;

  FavoriteRoute({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
  });

  factory FavoriteRoute.fromDoc(String id, Map<String, dynamic> data) {
    return FavoriteRoute(
      id: id,
      title: (data['title'] ?? '즐겨찾기') as String,
      start: FavPoint.fromMap(Map<String, dynamic>.from(data['start'] as Map)),
      end: FavPoint.fromMap(Map<String, dynamic>.from(data['end'] as Map)),
    );
  }

  String get subtitle => '${start.label} → ${end.label}';
}
