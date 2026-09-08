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

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flauncher/models/weather.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _weatherCacheKey = "weather_cache";

const _forecastUrl = "https://api.open-meteo.com/v1/forecast";
const _geocodingUrl = "https://geocoding-api.open-meteo.com/v1/search";

/// Fetches current weather from Open-Meteo (no API key required) and caches
/// the last successful result so the card renders instantly on cold boot.
class WeatherService extends ChangeNotifier {
  final SharedPreferences _sharedPreferences;
  final SettingsService _settingsService;
  final http.Client _client = http.Client();
  Timer? _refreshTimer;
  WeatherData? _currentWeather;
  bool _refreshing = false;

  WeatherService(this._sharedPreferences, this._settingsService) {
    _currentWeather = _restoreCache();
    _settingsService.addListener(_onSettingsChanged);
    _scheduleRefresh();
    unawaited(refresh());
  }

  bool get enabled => _settingsService.weatherEnabled;

  WeatherLocation? get location {
    final json = _settingsService.weatherLocationJson;
    if (json == null) {
      return null;
    }
    try {
      return WeatherLocation.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }
    catch (e) {
      return null;
    }
  }

  WeatherData? get currentWeather => _currentWeather;

  Future<List<WeatherLocation>> searchCities(String query, {String? language}) async {
    final languageCode = language
        ?? _settingsService.locale
        ?? Platform.localeName.split(RegExp(r"[-_]")).first;
    final url = "$_geocodingUrl?name=${Uri.encodeQueryComponent(query)}&count=5&language=$languageCode";
    final body = await _getJson(url);
    final results = body["results"] as List? ?? [];

    return results
        .whereType<Map<String, dynamic>>()
        .map(WeatherLocation.fromJson)
        .toList();
  }

  Future<void> refresh() async {
    final location = this.location;

    if (!enabled || location == null || _refreshing) {
      return;
    }

    _refreshing = true;
    try {
      final url = "$_forecastUrl"
          "?latitude=${location.latitude}"
          "&longitude=${location.longitude}"
          "&current=temperature_2m,weather_code,is_day"
          "&timezone=auto";
      final body = await _getJson(url);
      final current = body["current"];

      if (current is Map<String, dynamic>) {
        _currentWeather = WeatherData.fromJson(current);
        await _sharedPreferences.setString(_weatherCacheKey, jsonEncode(_currentWeather!.toJson()));
        notifyListeners();
      }
    }
    catch (e) {
      // Keep showing the cached weather; retry on the next tick.
      debugPrint("Weather refresh failed: $e");
    }
    finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _settingsService.removeListener(_onSettingsChanged);
    _client.close();
    super.dispose();
  }

  WeatherData? _restoreCache() {
    final json = _sharedPreferences.getString(_weatherCacheKey);
    if (json == null || json.isEmpty) {
      return null;
    }
    try {
      return WeatherData.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }
    catch (e) {
      return null;
    }
  }

  void _onSettingsChanged() {
    _scheduleRefresh();
    // Repaint for enable/location changes, then pick up fresh data as soon as
    // the triggered refresh completes.
    notifyListeners();
    unawaited(refresh());
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (enabled && location != null) {
      _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) => refresh());
    }
  }

  Future<dynamic> _getJson(String url) async {
    final response = await _get(url);

    if (response.statusCode != 200) {
      throw Exception("Open-Meteo returned HTTP ${response.statusCode}");
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<http.Response> _get(String url) async {
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await _client.get(Uri.parse(url), headers: {
          "User-Agent": "MTLauncher-Android",
        });

        if (response.statusCode < 500) {
          return response;
        }

        lastError = Exception("Open-Meteo returned HTTP ${response.statusCode}");
      }
      catch (e) {
        lastError = e;
      }

      await Future.delayed(Duration(milliseconds: 800 * attempt));
    }

    throw lastError ?? Exception("Request failed");
  }
}