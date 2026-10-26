import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/weather_model.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.weatherapi.com/v1/forecast.json';

  Future<WeatherData> fetchWeather(String city) async {
    final apiKey = dotenv.env['WEATHER_API_KEY']?.trim();

    if (apiKey == null ||
        apiKey.isEmpty ||
        apiKey == 'YOUR_KEY_HERE') {
      throw Exception(
        'Weather API key is missing. Add WEATHER_API_KEY to your .env file.',
      );
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'key': apiKey,
        'q': city.trim(),
        'days': '5',
        'aqi': 'no',
        'alerts': 'no',
      },
    );

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return WeatherData.fromJson(data);
      }

      final error = data['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String? ??
          'Unable to retrieve weather data.';

      throw Exception(message);
    } on FormatException {
      throw Exception('The weather server returned an invalid response.');
    } on http.ClientException {
      throw Exception('Network error. Please check your internet connection.');
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception(
        'Unable to connect to the weather service. Please try again.',
      );
    }
  }
}
