import 'package:cloud_firestore/cloud_firestore.dart';

import '../home/home_card_order.dart';


class UserSettingsStore {
  UserSettingsStore({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _fieldOrder = 'homeCardOrderV1';
  static const String _spKeyLegacy = 'home_card_order_v1'; // 기존 SharedPrefs 키(있으면)

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('user_settings').doc(uid);

  // enum -> String
  List<String> _encode(List<HomeCardId> order) => order.map((e) => e.name).toList();

  // String -> enum (+삭제된 enum 방어 +누락 보정)
  List<HomeCardId> _decode(dynamic raw) {
    final out = <HomeCardId>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is! String) continue;
        final found = HomeCardId.values.where((e) => e.name == v).toList();
        if (found.isNotEmpty) out.add(found.first);
      }
    }
    for (final d in HomeCardOrderStore.defaultOrder) {
      if (!out.contains(d)) out.add(d);
    }
    return out;
  }

  /// 1) Firestore -> 2) (선택) SharedPrefs 마이그레이션 -> 3) default 저장
  Future<List<HomeCardId>> loadHomeCardOrder(String uid) async {
    // 1) Firestore 우선
    final snap = await _doc(uid).get();
    final data = snap.data();
    final fromDb = data?[_fieldOrder];
    if (fromDb != null) {
      return _decode(fromDb);
    }

    // 3) 아무것도 없으면 default를 DB에 한번 저장
    final def = [...HomeCardOrderStore.defaultOrder];
    await saveHomeCardOrder(uid, def);
    return def;
  }

  Future<void> saveHomeCardOrder(String uid, List<HomeCardId> order) async {
    await _doc(uid).set({
      _fieldOrder: _encode(order),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 실시간 반영이 필요하면 사용(선택)
  Stream<List<HomeCardId>> watchHomeCardOrder(String uid) {
    return _doc(uid).snapshots().map((s) {
      final data = s.data();
      final raw = data?[_fieldOrder];
      if (raw == null) return [...HomeCardOrderStore.defaultOrder];
      return _decode(raw);
    });
  }
}
