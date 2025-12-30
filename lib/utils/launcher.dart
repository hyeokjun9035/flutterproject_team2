// lib/utils/launcher.dart
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternal(Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    throw Exception('Could not launch $uri');
  }
}

Future<void> openUrl(String url) => openExternal(Uri.parse(url));

/// 기상청 날씨누리 "디지털예보" (2021+ 경로)
/// - code는 있으면 넣고, 없으면 null로 두면 됨
Uri buildWeatherNuriDigitalForecastUrl({
  required double lat,
  required double lon,
  String? code,
  bool hourly1h = false, // false면 3시간 간격(N), true면 1시간 간격(Y)
  String unit = 'm/s',
  String ts = '',
}) {
  final qp = <String, String>{
    'hr1': hourly1h ? 'Y' : 'N',
    'lat': lat.toString(),
    'lon': lon.toString(),
    'unit': unit,
    'ts': ts,
  };
  if (code != null && code.isNotEmpty) qp['code'] = code;

  return Uri.https(
    'www.weather.go.kr',
    '/w/wnuri-fct2021/main/digital-forecast.do',
    qp,
  );
}

/// 에어코리아 - 우리동네 대기정보
Uri airKoreaMyNeighborhoodUrl() => Uri.https(
  'www.airkorea.or.kr',
  '/web/link/',
  {'pMENU_NO': '96'},
);
