import 'package:shared_preferences/shared_preferences.dart';

enum HomeCardId {
  weatherHero,
  carry,
  air,
  hourly,
  weekly,
  transit,
  nearbyIssues,
}

class HomeCardOrderStore {
  static const _key = 'home_card_order_v1';

  static const defaultOrder = <HomeCardId>[
    HomeCardId.weatherHero,
    HomeCardId.carry,
    HomeCardId.air,
    HomeCardId.hourly,
    HomeCardId.weekly,
    HomeCardId.transit,
    HomeCardId.nearbyIssues,
  ];

  static String label(HomeCardId id) {
    switch (id) {
      case HomeCardId.weatherHero:
        return '현재 날씨';
      case HomeCardId.carry:
        return '오늘 챙길 것';
      case HomeCardId.air:
        return '대기질';
      case HomeCardId.hourly:
        return '시간대별';
      case HomeCardId.weekly:
        return '주간';
      case HomeCardId.transit:
        return '출근/즐겨찾기 루트';
      case HomeCardId.nearbyIssues:
        return '내 주변 이슈';
    }
  }

  static Future<List<HomeCardId>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    if (raw == null || raw.isEmpty) return [...defaultOrder];

    final out = <HomeCardId>[];
    for (final s in raw) {
      try {
        out.add(HomeCardId.values.byName(s));
      } catch (_) {}
    }

    // 누락된 카드가 있으면 default로 보강
    for (final id in defaultOrder) {
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  static Future<void> save(List<HomeCardId> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, order.map((e) => e.name).toList());
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

