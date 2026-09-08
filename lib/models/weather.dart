/*
 * FLauncher
 * Copyright (C) 2024 Oscar Rojas
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/// A city resolved through the Open-Meteo geocoding API.
class WeatherLocation {
  final String name;
  final String countryCode;
  final double latitude;
  final double longitude;

  const WeatherLocation({
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
  });

  String get label => "$name,$countryCode";

  factory WeatherLocation.fromJson(Map<String, dynamic> json) => WeatherLocation(
    name: json["name"] as String? ?? "",
    countryCode: json["country_code"] as String? ?? "",
    latitude: (json["latitude"] as num?)?.toDouble() ?? 0,
    longitude: (json["longitude"] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "country_code": countryCode,
    "latitude": latitude,
    "longitude": longitude,
  };
}

/// Current conditions as returned by the Open-Meteo forecast API.
class WeatherData {
  final double temperature;
  final int weatherCode;
  final bool isDay;
  final DateTime fetchedAt;

  const WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.isDay,
    required this.fetchedAt,
  });

  WeatherKind get kind => weatherKindForCode(weatherCode);

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    temperature: (json["temperature_2m"] as num?)?.toDouble() ?? 0,
    weatherCode: json["weather_code"] as int? ?? -1,
    isDay: json["is_day"] as int? == 1,
    fetchedAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    "temperature_2m": temperature,
    "weather_code": weatherCode,
    "is_day": isDay ? 1 : 0,
    "fetched_at": fetchedAt.toIso8601String(),
  };
}

enum WeatherKind {
  clear,
  mostlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  lightRain,
  rain,
  heavyRain,
  freezingRain,
  lightSnow,
  snow,
  heavySnow,
  showers,
  snowShowers,
  thunderstorm,
  thunderstormHail,
}

/// Maps WMO weather interpretation codes (as used by Open-Meteo) to a coarse
/// weather kind. Unknown codes fall back to partly cloudy.
WeatherKind weatherKindForCode(int code) {
  switch (code) {
    case 0:
      return WeatherKind.clear;
    case 1:
      return WeatherKind.mostlyClear;
    case 2:
      return WeatherKind.partlyCloudy;
    case 3:
      return WeatherKind.overcast;
    case 45:
    case 48:
      return WeatherKind.fog;
    case 51:
    case 53:
    case 55:
      return WeatherKind.drizzle;
    case 56:
    case 57:
    case 66:
    case 67:
      return WeatherKind.freezingRain;
    case 61:
      return WeatherKind.lightRain;
    case 63:
      return WeatherKind.rain;
    case 65:
      return WeatherKind.heavyRain;
    case 71:
      return WeatherKind.lightSnow;
    case 73:
      return WeatherKind.snow;
    case 75:
    case 77:
      return WeatherKind.heavySnow;
    case 80:
    case 81:
    case 82:
      return WeatherKind.showers;
    case 85:
    case 86:
      return WeatherKind.snowShowers;
    case 95:
      return WeatherKind.thunderstorm;
    case 96:
    case 99:
      return WeatherKind.thunderstormHail;
    default:
      return WeatherKind.partlyCloudy;
  }
}