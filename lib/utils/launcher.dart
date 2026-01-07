// lib/utils/launcher.dart
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternal(Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) throw Exception('Could not launch $uri');
}

/// ✅ 날씨누리 디지털예보: code가 핵심
Uri buildWeatherNuriDigitalForecastUrl({
  required String code,           // ⭐ 필수
  bool hourly1h = false,          // hr1=Y/N
  String unit = 'm/s',
  String ts = '',
}) {
  return Uri.https(
    'www.weather.go.kr',
    '/w/wnuri-fct2021/main/digital-forecast.do',
    {
      'code': code,
      'hr1': hourly1h ? 'Y' : 'N',
      'unit': unit,
      'ts': ts,
    },
  );
}

/// ✅ code 없을 때 폴백(최소한 “날씨누리”로는 이동)
Uri weatherNuriHomeUrl() => Uri.https('www.weather.go.kr', '/w/index.do');

Future<void> openWeatherNuri({
  required double lat,
  required double lon,
  String? code,
}) async {
  final uri = (code != null && code.isNotEmpty)
      ? buildWeatherNuriDigitalForecastUrl(code: code)
      : weatherNuriHomeUrl();
  await openExternal(uri);
}

/// ✅ 에어코리아 - 우리동네 대기정보(근접측정소: TM좌표 기반)
Uri airKoreaRealSearchByTm({required int tmX, required int tmY}) => Uri.https(
  'www.airkorea.or.kr',
  '/web/realSearch',
  {
    'pMENU_NO': '97',
    'tm_x': tmX.toString(),
    'tm_y': tmY.toString(),
  },
);

Uri airKoreaHomeUrl() => Uri.https('www.airkorea.or.kr', '/');

/// ✅ 구글맵 도보 길찾기(앱 없으면 웹으로도 열림)
Uri buildGoogleWalkDirectionsUrl({
  required double startLat,
  required double startLon,
  required double endLat,
  required double endLon,
}) {
  return Uri.https(
    'www.google.com',
    '/maps/dir/',
    {
      'api': '1',
      'origin': '$startLat,$startLon',
      'destination': '$endLat,$endLon',
      'travelmode': 'walking', // ⭐ 핵심
      // 'dir_action': 'navigate', // (선택) 이걸 켜면 "내비게이션"으로 가는데,
      // 지역/상황에 따라 도보 내비게이션이 애매하면 그냥 빼는 걸 추천
    },
  );
}

Future<void> openWalkDirections({
  required double startLat,
  required double startLon,
  required double endLat,
  required double endLon,
}) async {
  final uri = buildGoogleWalkDirectionsUrl(
    startLat: startLat,
    startLon: startLon,
    endLat: endLat,
    endLon: endLon,
  );
  await openExternal(uri);
}
