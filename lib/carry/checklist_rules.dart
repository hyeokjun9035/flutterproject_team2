import '../data/models.dart';
import 'checklist_models.dart';

bool matchesRule(ChecklistItem item, DashboardData d) {
  final r = item.rules;

  int? toInt(dynamic v) => v is int ? v : int.tryParse('$v');
  double? toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');

  List<int>? listInt(String k) {
    final raw = r[k];
    if (raw is! List) return null;
    final v = raw.map(toInt).whereType<int>().toList();
    return v.isEmpty ? null : v;
  }

  bool minOk(String key, num value) {
    final m = toDouble(r[key]);
    return m == null ? true : value >= m;
  }

  bool maxOk(String key, num value) {
    final m = toDouble(r[key]);
    return m == null ? true : value <= m;
  }

  final pty = d.now.pty ?? 0;
  final rn1 = d.now.rn1 ?? 0;
  final temp = d.now.temp ?? 0;
  final wind = d.now.wind ?? 0;
  final reh = d.now.humidity ?? 0;
  final pm10 = d.air.pm10 ?? 0;
  final pm25 = d.air.pm25 ?? 0;

  final ptyIn = listInt('ptyIn');
  if (ptyIn != null && !ptyIn.contains(pty)) return false;

  final ptyNotIn = listInt('ptyNotIn');
  if (ptyNotIn != null && ptyNotIn.contains(pty)) return false;

  if (!minOk('rn1Min', rn1)) return false;
  if (!maxOk('rn1Max', rn1)) return false;

  if (!minOk('tempMin', temp)) return false;
  if (!maxOk('tempMax', temp)) return false;

  if (!minOk('windMin', wind)) return false;

  if (!minOk('rehMin', reh)) return false;
  if (!maxOk('rehMax', reh)) return false;

  if (!minOk('pm10Min', pm10)) return false;
  if (!minOk('pm25Min', pm25)) return false;

  return true;
}
