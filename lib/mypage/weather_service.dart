import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class WeatherService {
  final String _baseUrl = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst";

  Future<List<dynamic>> fetchWeather() async {
    // 1. 키 가져오기 (비어있을 경우 대비)
    final serviceKey = dotenv.env['KMA_SERVICE_KEY'] ?? "";

    // 2. 시간 설정 (기상청은 매시 40~45분은 되어야 해당 시각 데이터가 생성됨)
    // 현재 시간에서 1시간을 빼는 것이 가장 안정적으로 데이터를 가져옵니다.
    DateTime now = DateTime.now();
    DateTime baseDateTime = now.subtract(const Duration(hours: 1));

    String baseDate = DateFormat('yyyyMMdd').format(baseDateTime);
    String baseTime = DateFormat('HH00').format(baseDateTime);

    // 3. URL 조립 (Uri.encodeFull은 사용하지 마세요. 키가 이미 인코딩된 경우 오류 발생)
    final String url = "$_baseUrl?serviceKey=$serviceKey&pageNo=1&numOfRows=10&dataType=JSON&base_date=$baseDate&base_time=$baseTime&nx=60&ny=127";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 기상청 특유의 에러 결과 확인 (정상 코드는 '00')
        final header = data['response']['header'];
        if (header['resultCode'] != '00') {
          print("⚠️ 기상청 API 응답 에러: ${header['resultMsg']}");
          throw Exception(header['resultMsg']);
        }

        return data['response']['body']['items']['item'];
      } else {
        throw Exception('HTTP 서버 에러: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ 날씨 데이터 패치 중 오류 발생: $e");
      rethrow;
    }
  }
}