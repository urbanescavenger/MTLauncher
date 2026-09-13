import 'dart:async';
import 'dart:convert';

import 'package:flauncher/models/weather.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  Future<SharedPreferences> newPreferences() async {
    SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
    return SharedPreferences.getInstance();
  }

  /// The service's constructor fires refresh() unawaited; poll until the
  /// auto-location cache appears (or not) so tests are not timing-dependent.
  Future<void> settle(SharedPreferences preferences, {bool expectCache = true}) async {
    for (var i = 0; i < 100; i++) {
      final present = preferences.getString("weather_auto_location_cache") != null;
      if (present == expectCache) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // One more round for the forecast write that follows the location resolve.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  setUp(() {
    SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  });

  test("auto-location falls back to the next provider when one fails", () async {
    final preferences = await newPreferences();
    final settingsService = SettingsService(preferences);
    await settingsService.setWeatherEnabled(true);

    final hosts = <String>[];
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host == "get.geojs.io") {
        return http.Response("", 500);
      }
      if (request.url.host == "ipwho.is") {
        return http.Response(jsonEncode({
          "latitude": 39.9,
          "longitude": 116.4,
          "city": "Beijing",
          "country_code": "CN",
        }), 200);
      }
      return http.Response("", 404);
    });

    final weatherService = WeatherService(preferences, settingsService, client: client);
    await settle(preferences);

    expect(hosts, containsAllInOrder(["get.geojs.io", "ipwho.is"]));
    expect(weatherService.location?.name, "Beijing");

    weatherService.dispose();
  });

  test("auto-location fails cleanly when every provider fails", () async {
    final preferences = await newPreferences();
    final settingsService = SettingsService(preferences);
    await settingsService.setWeatherEnabled(true);

    final client = MockClient((request) async => http.Response("", 500));

    final weatherService = WeatherService(preferences, settingsService, client: client);
    await settle(preferences, expectCache: false);

    expect(preferences.getString("weather_auto_location_cache"), isNull);
    expect(weatherService.location, isNull);
    expect(weatherService.currentWeather, isNull);

    weatherService.dispose();
  });

  test("manual location fetches and caches weather", () async {
    final preferences = await newPreferences();
    final settingsService = SettingsService(preferences);
    await settingsService.setWeatherEnabled(true);
    await settingsService.setWeatherAutoLocation(false);
    await settingsService.setWeatherLocationJson(jsonEncode({
      "name": "Beijing",
      "country_code": "CN",
      "latitude": 39.9,
      "longitude": 116.4,
    }));

    final hosts = <String>[];
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host == "api.open-meteo.com") {
        return http.Response(jsonEncode({
          "current": {
            "temperature_2m": 21.4,
            "weather_code": 0,
            "is_day": 1,
          }
        }), 200);
      }
      return http.Response("", 404);
    });

    final weatherService = WeatherService(preferences, settingsService, client: client);
    for (var i = 0; i < 100 && weatherService.currentWeather == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(hosts, ["api.open-meteo.com"]);
    expect(weatherService.currentWeather?.temperature, 21.4);
    expect(weatherService.currentWeather?.kind, WeatherKind.clear);
    expect(preferences.getString("weather_cache"), isNotNull);

    weatherService.dispose();
  });
}