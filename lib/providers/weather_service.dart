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
const _weatherAutoLocationCacheKey = "weather_auto_location_cache";

const _forecastUrl = "https://api.open-meteo.com/v1/forecast";
const _geocodingUrl = "https://geocoding-api.open-meteo.com/v1/search";
const _ipGeolocationUrl = "https://get.geojs.io/v1/ip/geo.json";

/// How long an IP-resolved location is trusted before re-resolving.
const _autoLocationMaxAge = Duration(hours: 24);

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
    if (_settingsService.weatherAutoLocation) {
      return _autoLocation;
    }
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
    if (!enabled || _refreshing) {
      return;
    }

    _refreshing = true;
    try {
      var location = this.location;

      if (_settingsService.weatherAutoLocation && (location == null || _autoLocationStale)) {
        // First run (no location yet) or a stale one: resolve via IP. On
        // failure keep whatever is cached and retry on the next tick.
        if (await _resolveAutoLocation()) {
          location = _autoLocation;
          notifyListeners();
        }
      }

      if (location == null) {
        return;
      }

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
    // In auto mode the location may not exist yet (IP lookup pending), the
    // timer still runs so each tick retries the resolution.
    if (enabled && (_settingsService.weatherAutoLocation || location != null)) {
      _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) => refresh());
    }
  }

  WeatherLocation? get _autoLocation {
    final json = _sharedPreferences.getString(_weatherAutoLocationCacheKey);
    if (json == null || json.isEmpty) {
      return null;
    }
    try {
      final cache = jsonDecode(json) as Map<String, dynamic>;
      return WeatherLocation.fromJson(cache["location"] as Map<String, dynamic>);
    }
    catch (e) {
      return null;
    }
  }

  bool get _autoLocationStale {
    final json = _sharedPreferences.getString(_weatherAutoLocationCacheKey);
    if (json == null || json.isEmpty) {
      return true;
    }
    try {
      final cache = jsonDecode(json) as Map<String, dynamic>;
      final resolvedAt = DateTime.tryParse(cache["resolved_at"] as String? ?? "");
      return resolvedAt == null || DateTime.now().difference(resolvedAt) > _autoLocationMaxAge;
    }
    catch (e) {
      return true;
    }
  }

  /// Resolves the approximate location from the device's public IP (GeoJS,
  /// no API key). Returns false when the lookup fails.
  Future<bool> _resolveAutoLocation() async {
    try {
      final body = await _getJson(_ipGeolocationUrl);
      final latitude = double.tryParse(body["latitude"]?.toString() ?? "");
      final longitude = double.tryParse(body["longitude"]?.toString() ?? "");
      final name = body["city"]?.toString() ?? "";
      final countryCode = body["country_code"]?.toString() ?? "";

      if (latitude == null || longitude == null || name.isEmpty) {
        return false;
      }

      final location = WeatherLocation(
          name: name,
          countryCode: countryCode,
          latitude: latitude,
          longitude: longitude
      );
      await _sharedPreferences.setString(_weatherAutoLocationCacheKey, jsonEncode({
        "location": location.toJson(),
        "resolved_at": DateTime.now().toIso8601String(),
      }));
      return true;
    }
    catch (e) {
      debugPrint("IP location lookup failed: $e");
      return false;
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