/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
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

import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appHighlightAnimationEnabledKey = "app_highlight_animation_enabled";
const _appKeyClickEnabledKey = "app_key_click_enabled";
const _autoHideAppBar = "auto_hide_app_bar";
const _gradientUuidKey = "gradient_uuid";
const _backButtonAction = "back_button_action";
const _dateFormat = "date_format";
const _favoriteCategoryIdKey = "favorite_category_id";
const _localeKey = "locale";
const _showCategoryTitles = "show_category_titles";
const _showDateInStatusBar = "show_date_in_status_bar";
const _showTimeInStatusBar = "show_time_in_status_bar";
const _timeFormat = "time_format";
const _weatherEnabledKey = "weather_enabled";
const _weatherAutoLocationKey = "weather_auto_location";
const _weatherLocationKey = "weather_location";

class SettingsService extends ChangeNotifier {
  static final defaultDateFormat = "EEEE d";
  static final defaultTimeFormat = "H:mm";
  final SharedPreferences _sharedPreferences;


  bool get appHighlightAnimationEnabled => _sharedPreferences.getBool(_appHighlightAnimationEnabledKey) ?? true;

  bool get appKeyClickEnabled => _sharedPreferences.getBool(_appKeyClickEnabledKey) ?? true;

  bool get autoHideAppBarEnabled => _sharedPreferences.getBool(_autoHideAppBar) ?? false;

  bool get showCategoryTitles => _sharedPreferences.getBool(_showCategoryTitles) ?? true;

  bool get showDateInStatusBar => _sharedPreferences.getBool(_showDateInStatusBar) ?? true;

  bool get showTimeInStatusBar => _sharedPreferences.getBool(_showTimeInStatusBar) ?? true;

  String? get gradientUuid => _sharedPreferences.getString(_gradientUuidKey);

  int? get favoriteCategoryId {
    final value = _sharedPreferences.getInt(_favoriteCategoryIdKey);
    return value == null || value <= 0 ? null : value;
  }

  String? get locale {
    final value = _sharedPreferences.getString(_localeKey);
    return value == null || value.isEmpty ? null : value;
  }

  String get backButtonAction => _sharedPreferences.getString(_backButtonAction) ?? BACK_BUTTON_ACTION_NOTHING;

  String get dateFormat => _sharedPreferences.getString(_dateFormat) ?? defaultDateFormat;

  String get timeFormat => _sharedPreferences.getString(_timeFormat) ?? defaultTimeFormat;

  bool get weatherEnabled => _sharedPreferences.getBool(_weatherEnabledKey) ?? false;

  bool get weatherAutoLocation => _sharedPreferences.getBool(_weatherAutoLocationKey) ?? true;

  String? get weatherLocationJson {
    final value = _sharedPreferences.getString(_weatherLocationKey);
    return value == null || value.isEmpty ? null : value;
  }

  SettingsService(
    this._sharedPreferences
  );

  Future<void> set(String key, bool value) async {
    await _sharedPreferences.setBool(key, value);
    notifyListeners();
  }

  Future<void> setAppHighlightAnimationEnabled(bool value) async {
    return set(_appHighlightAnimationEnabledKey, value);
  }

  Future<void> setAppKeyClickEnabled(bool value) async {
    return set(_appKeyClickEnabledKey, value);
  }

  Future<void> setAutoHideAppBarEnabled(bool value) async {
    return set(_autoHideAppBar, value);
  }

  Future<void> setGradientUuid(String value) async {
    await _sharedPreferences.setString(_gradientUuidKey, value);
    notifyListeners();
  }

  Future<void> setFavoriteCategoryId(int? value) async {
    if (value == null) {
      await _sharedPreferences.remove(_favoriteCategoryIdKey);
    } else {
      await _sharedPreferences.setInt(_favoriteCategoryIdKey, value);
    }
    notifyListeners();
  }

  Future<void> setLocale(String? value) async {
    if (value == null || value.isEmpty) {
      await _sharedPreferences.remove(_localeKey);
    } else {
      await _sharedPreferences.setString(_localeKey, value);
    }
    notifyListeners();
  }

  Future<void> setBackButtonAction(String value) async {
    await _sharedPreferences.setString(_backButtonAction, value);
    notifyListeners();
  }

  Future<void> setDateTimeFormat(String dateFormatString, String timeFormatString) async {
    await Future.wait([
      _sharedPreferences.setString(_dateFormat, dateFormatString),
      _sharedPreferences.setString(_timeFormat, timeFormatString)
    ]);
    notifyListeners();
  }

  Future<void> setShowCategoryTitles(bool show) async {
    return set(_showCategoryTitles, show);
  }

  Future<void> setShowDateInStatusBar(bool show) async {
    return set(_showDateInStatusBar, show);
  }

  Future<void> setShowTimeInStatusBar(bool show) async {
    return set(_showTimeInStatusBar, show);
  }

  Future<void> setWeatherEnabled(bool value) async {
    return set(_weatherEnabledKey, value);
  }

  Future<void> setWeatherAutoLocation(bool value) async {
    return set(_weatherAutoLocationKey, value);
  }

  Future<void> setWeatherLocationJson(String? value) async {
    if (value == null || value.isEmpty) {
      await _sharedPreferences.remove(_weatherLocationKey);
    } else {
      await _sharedPreferences.setString(_weatherLocationKey, value);
    }
    notifyListeners();
  }
}
