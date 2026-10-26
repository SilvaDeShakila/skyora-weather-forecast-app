class WeatherData {
  final String cityName;
  final String region;
  final String country;
  final double temperature;
  final double feelsLike;
  final String condition;
  final String iconUrl;
  final int humidity;
  final double windKph;
  final double pressureMb;
  final double visibilityKm;
  final double uv;
  final bool isDay;
  final DateTime lastUpdated;
  final String sunrise;
  final String sunset;
  final List<ForecastDay> forecast;
  final List<HourlyForecast> hourlyForecast;

  const WeatherData({
    required this.cityName,
    required this.region,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.iconUrl,
    required this.humidity,
    required this.windKph,
    required this.pressureMb,
    required this.visibilityKm,
    required this.uv,
    required this.isDay,
    required this.lastUpdated,
    required this.sunrise,
    required this.sunset,
    required this.forecast,
    required this.hourlyForecast,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final condition = current['condition'] as Map<String, dynamic>;
    final forecastRoot = json['forecast'] as Map<String, dynamic>;
    final forecastDays = forecastRoot['forecastday'] as List<dynamic>;

    return WeatherData(
      cityName: location['name'] as String? ?? '',
      region: location['region'] as String? ?? '',
      country: location['country'] as String? ?? '',
      temperature: (current['temp_c'] as num).toDouble(),
      feelsLike: (current['feelslike_c'] as num).toDouble(),
      condition: condition['text'] as String? ?? 'Unknown',
      iconUrl: condition['icon'] as String? ?? '',
      humidity: (current['humidity'] as num).toInt(),
      windKph: (current['wind_kph'] as num).toDouble(),
      pressureMb: (current['pressure_mb'] as num).toDouble(),
      visibilityKm: (current['vis_km'] as num).toDouble(),
      uv: (current['uv'] as num).toDouble(),
      isDay: (current['is_day'] as num).toInt() == 1,
      lastUpdated: DateTime.tryParse(
            current['last_updated'] as String? ?? '',
          ) ??
          DateTime.now(),
      sunrise: forecastDays.isNotEmpty
          ? ((forecastDays.first as Map<String, dynamic>)['astro']
                  as Map<String, dynamic>)['sunrise'] as String? ??
              '--'
          : '--',
      sunset: forecastDays.isNotEmpty
          ? ((forecastDays.first as Map<String, dynamic>)['astro']
                  as Map<String, dynamic>)['sunset'] as String? ??
              '--'
          : '--',
      forecast: forecastDays
          .map((day) => ForecastDay.fromJson(day as Map<String, dynamic>))
          .toList(),
      hourlyForecast: forecastDays
          .expand((day) => (day as Map<String, dynamic>)['hour'] as List<dynamic>)
          .map((hour) => HourlyForecast.fromJson(hour as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ForecastDay {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final double avgTemp;
  final String condition;
  final String iconUrl;
  final int chanceOfRain;
  final double maxWindKph;
  final double uv;

  const ForecastDay({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.avgTemp,
    required this.condition,
    required this.iconUrl,
    required this.chanceOfRain,
    required this.maxWindKph,
    required this.uv,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    final day = json['day'] as Map<String, dynamic>;
    final weatherCondition = day['condition'] as Map<String, dynamic>;

    return ForecastDay(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      maxTemp: (day['maxtemp_c'] as num).toDouble(),
      minTemp: (day['mintemp_c'] as num).toDouble(),
      avgTemp: (day['avgtemp_c'] as num).toDouble(),
      condition: weatherCondition['text'] as String? ?? 'Unknown',
      iconUrl: weatherCondition['icon'] as String? ?? '',
      chanceOfRain: (day['daily_chance_of_rain'] as num? ?? 0).toInt(),
      maxWindKph: (day['maxwind_kph'] as num).toDouble(),
      uv: (day['uv'] as num).toDouble(),
    );
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final String condition;
  final String iconUrl;
  final int chanceOfRain;
  final double windKph;

  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.condition,
    required this.iconUrl,
    required this.chanceOfRain,
    required this.windKph,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    final weatherCondition = json['condition'] as Map<String, dynamic>;

    return HourlyForecast(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      temperature: (json['temp_c'] as num).toDouble(),
      condition: weatherCondition['text'] as String? ?? 'Unknown',
      iconUrl: weatherCondition['icon'] as String? ?? '',
      chanceOfRain: (json['chance_of_rain'] as num? ?? 0).toInt(),
      windKph: (json['wind_kph'] as num).toDouble(),
    );
  }
}
