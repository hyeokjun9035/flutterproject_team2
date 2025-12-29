import 'package:flutter/material.dart';
import '../data/models.dart'; // 경로는 프로젝트에 맞게 수정

String weatherSummary({int? sky, int? pty}) {
  // ✅ PTY 먼저 (예보에서 5/6/7도 나올 수 있어서 포함)
  switch (pty ?? 0) {
    case 1:
      return '비';
    case 2:
      return '비/눈';
    case 3:
      return '눈';
    case 4:
      return '소나기';
    case 5:
      return '빗방울';
    case 6:
      return '빗방울/눈날림';
    case 7:
      return '눈날림';
  }

  // ✅ SKY (1 맑음 / 2 구름조금 / 3 구름많음 / 4 흐림)
  switch (sky) {
    case 1:
      return '맑음';
    case 2:
      return '구름조금';
    case 3:
      return '구름많음';
    case 4:
      return '흐림';
  }

  // ✅ sky도 없고 pty도 0이면: 실황에서 흔한 케이스 → 기본값을 “맑음/강수없음”으로
  return '맑음';
}


Widget valueChip({
  required IconData icon,
  required String text,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.9)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

enum DustGrade { good, normal, bad, veryBad, unknown }

DustGrade gradePm10(int? v) {
  if (v == null) return DustGrade.unknown;
  if (v <= 30) return DustGrade.good;
  if (v <= 80) return DustGrade.normal;
  if (v <= 150) return DustGrade.bad;
  return DustGrade.veryBad;
}

DustGrade gradePm25(int? v) {
  if (v == null) return DustGrade.unknown;
  if (v <= 15) return DustGrade.good;
  if (v <= 35) return DustGrade.normal;
  if (v <= 75) return DustGrade.bad;
  return DustGrade.veryBad;
}

String gradeLabel(DustGrade g) {
  switch (g) {
    case DustGrade.good:
      return '좋음';
    case DustGrade.normal:
      return '보통';
    case DustGrade.bad:
      return '나쁨';
    case DustGrade.veryBad:
      return '매우나쁨';
    case DustGrade.unknown:
      return '정보없음';
  }
}

Color gradeColor(DustGrade g) {
  switch (g) {
    case DustGrade.good:
      return Colors.green;
    case DustGrade.normal:
      return Colors.blue;
    case DustGrade.bad:
      return Colors.orange;
    case DustGrade.veryBad:
      return Colors.red;
    case DustGrade.unknown:
      return Colors.grey;
  }
}

String maskRecommendation({required int? pm25}) {
  final g = gradePm25(pm25);
  switch (g) {
    case DustGrade.good:
    case DustGrade.normal:
      return '마스크 선택';
    case DustGrade.bad:
      return 'KF80 권장';
    case DustGrade.veryBad:
      return 'KF94 권장';
    case DustGrade.unknown:
      return '마스크 정보없음';
  }
}

/// ✅ 체크리스트 icon 키(예시 15개) -> Material Icon 매핑
IconData iconFromKey(String? key) {
  final k = (key ?? '').trim().toLowerCase();

  switch (k) {
  // 1) 기본
    case 'umbrella': return Icons.umbrella;
    case 'mask': return Icons.masks;
    case 'jacket': return Icons.checkroom;
    case 'hot': return Icons.local_fire_department;
    case 'water': return Icons.water_drop;

  // 2) 생활/행동
    case 'laundry': return Icons.local_laundry_service;
    case 'clock':   return Icons.schedule; // 칼퇴/시간관리 같은 용도
    case 'warning': return Icons.warning_amber_rounded;

  // 3) 이동
    case 'bus':   return Icons.directions_bus;
    case 'subway':return Icons.directions_subway;
    case 'walk':  return Icons.directions_walk;

  // 4) 날씨/상태
    case 'sun':   return Icons.wb_sunny;
    case 'cloud': return Icons.cloud_queue;
    case 'rain':  return Icons.umbrella; // 별도 키 쓰면 우산 아이콘 재사용
    case 'snow':  return Icons.ac_unit;

  // 5) 의복 디테일(너희가 쓰는 키)
    case 'shorts':   return Icons.accessibility_new; // 반바지 느낌 대체
    case 'socks':    return Icons.hiking; // 양말 전용이 없어서 대체(원하면 다른걸로 변경 가능)
    case 'innerwear':return Icons.checkroom;

    default:
      return Icons.check_circle_outline;
  }
}

/// ✅ type(bring/avoid/action) 스타일
class CarryTypeStyle {
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  const CarryTypeStyle(this.label, this.fg, this.bg, this.border);
}

CarryTypeStyle styleFromType(String? type) {
  final t = (type ?? '').trim().toLowerCase();
  // 원하는 톤으로 바꾸기 쉬움
  if (t == 'bring') {
    const fg = Color(0xFF36D399); // green-ish
    return CarryTypeStyle('챙기기', fg, Color(0x2636D399), Color(0x5536D399));
  }
  if (t == 'avoid') {
    const fg = Color(0xFFF97316); // orange-ish
    return CarryTypeStyle('주의', fg, Color(0x26F97316), Color(0x55F97316));
  }
  // action (기본)
  const fg = Color(0xFF60A5FA); // blue-ish
  return CarryTypeStyle('추천', fg, Color(0x2660A5FA), Color(0x5560A5FA));
}

/// ✅ 타입 배지(칩)
Widget typeChip(String? type) {
  final s = styleFromType(type);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: s.bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: s.border),
    ),
    child: Text(
      s.label,
      style: TextStyle(color: s.fg, fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );
}
