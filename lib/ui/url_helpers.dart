import 'package:url_launcher/url_launcher.dart';

Uri buildWeatherNuriDigitalForecastUrl({
  required double lat,
  required double lon,
  String? code, // 있으면 넣고, 없으면 null
}) {
  final qp = <String, String>{
    'hr1': 'N',
    'lat': lat.toString(),
    'lon': lon.toString(),
    'unit': 'm/s',
    'ts': '',
  };
  if (code != null && code.isNotEmpty) qp['code'] = code;

  return Uri.https(
    'www.weather.go.kr'
  );
}

Future<void> openExternal(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
