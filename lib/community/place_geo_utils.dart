import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeoInfo {
  final String? name;    // 동/읍/면 우선
  final String? address; // "도 시 구 동 도로명" 형태
  const GeoInfo({this.name, this.address});
}

String _t(String? s) => (s ?? '').trim().replaceFirst(RegExp(r'^KR\s+'), '');

int _rankLabel(String? label) {
  if (label == null || label.trim().isEmpty) return 0;
  final v = label.trim();
  if (RegExp(r'(동|읍|면)$').hasMatch(v)) return 3;
  if (RegExp(r'(구|군)$').hasMatch(v)) return 2;
  return 1;
}

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

/// 좌표 -> (동 우선 name + 풀 address)
Future<GeoInfo?> reverseGeocodeFull(LatLng p) async {
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
        if (bestRank == 3) break; // 동/읍/면이면 바로 확정
      }
    }

    final address = _buildAddressFromPlacemark(bestPm ?? pms.first);
    return GeoInfo(name: bestName, address: address);
  } catch (_) {
    return null;
  }
}

/// "OO동 현재 날씨" 라벨용 (동/읍/면 최우선)
String regionLabelFromNameAddress({required String name, required String address}) {
  final n = _t(name);
  final a = _t(address);

  // 0) name이 이미 동/읍/면/구면 그걸 우선
  if (RegExp(r'(동|읍|면|구|군)$').hasMatch(n)) return n;

  // 1) 주소에서 동/읍/면 찾기
  final mDong = RegExp(r'([가-힣0-9·\-\s]+?(동|읍|면))').firstMatch(a);
  if (mDong != null) return mDong.group(1)!.trim();

  // 2) 없으면 구/군
  final mGu = RegExp(r'([가-힣0-9·\-\s]+?(구|군))').firstMatch(a);
  if (mGu != null) return mGu.group(1)!.trim();

  // 3) 마지막: 시/도 첫 토큰
  if (a.isNotEmpty) {
    final first = a.split(' ').first;
    final cleaned = first
        .replaceAll('특별자치시', '')
        .replaceAll('특별자치도', '')
        .replaceAll('특별시', '')
        .replaceAll('광역시', '')
        .replaceAll('자치시', '')
        .replaceAll('자치도', '')
        .replaceAll('도', '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : first;
  }

  return n.isNotEmpty ? n : "현재";
}