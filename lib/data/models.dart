class WeatherNow {
  final double? temp;     // T1H
  final double? humidity; // REH
  final double? wind;     // WSD
  final int? sky;         // SKY (예보일 때)
  final int? pty;         // PTY (예보/실황)
  final double? rn1;      // RN1 (1시간 강수량)

  const WeatherNow({
    this.temp,
    this.humidity,
    this.wind,
    this.sky,
    this.pty,
    this.rn1,
  });
}

class HourlyForecast {
  final String timeLabel; // "09시"
  final int? sky;
  final int? pty;
  final double? temp;

  const HourlyForecast({
    required this.timeLabel,
    this.sky,
    this.pty,
    this.temp,
  });
}

class WeatherAlert {
  final String title;
  final String? region;
  final String? timeText;

  const WeatherAlert({required this.title, this.region, this.timeText});
}

class AirQuality {
  final String gradeText;  // 좋음/보통/나쁨/매우나쁨
  final int? pm10;
  final int? pm25;

  const AirQuality({required this.gradeText, this.pm10, this.pm25});
}

class DashboardData {
  final String locationName;
  final DateTime updatedAt;
  final WeatherNow now;
  final List<HourlyForecast> hourly;
  final List<WeatherAlert> alerts;
  final AirQuality air;
  final List<DailyForecast> weekly;


  const DashboardData({
    required this.locationName,
    required this.updatedAt,
    required this.now,
    required this.hourly,
    required this.alerts,
    required this.air,
    this.weekly = const [],
  });
}

class DailyForecast {
  final String date; // "yyyyMMdd"
  final double? min;
  final double? max;
  final int? pop;
  final int? sky;
  final int? pty;
  final String? wfText;

  const DailyForecast({
    required this.date,
    this.min,
    this.max,
    this.pop,
    this.sky,
    this.pty,
    this.wfText,
  });
}
