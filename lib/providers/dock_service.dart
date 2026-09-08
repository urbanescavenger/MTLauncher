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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dockAppsKey = "dock_apps";

class DockService extends ChangeNotifier {
  final SharedPreferences _sharedPreferences;

  List<String> _packageNames;

  DockService(this._sharedPreferences) : _packageNames = _load(_sharedPreferences);

  List<String> get packageNames => List.unmodifiable(_packageNames);

  bool isPinned(String packageName) => _packageNames.contains(packageName);

  Future<void> pinApp(String packageName) async {
    if (!_packageNames.contains(packageName)) {
      _packageNames.add(packageName);
      notifyListeners();
      await _save();
    }
  }

  Future<void> unpinApp(String packageName) async {
    if (_packageNames.remove(packageName)) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> togglePin(String packageName) => isPinned(packageName)
      ? unpinApp(packageName)
      : pinApp(packageName);

  void reorderApp(int oldIndex, int newIndex) {
    if (oldIndex == newIndex
        || oldIndex < 0
        || oldIndex >= _packageNames.length
        || newIndex < 0
        || newIndex >= _packageNames.length) {
      return;
    }
    final packageName = _packageNames.removeAt(oldIndex);
    _packageNames.insert(newIndex, packageName);
    notifyListeners();
  }

  Future<void> saveOrder() async {
    await _save();
  }

  static List<String> _load(SharedPreferences sharedPreferences) {
    try {
      final String? raw = sharedPreferences.getString(_dockAppsKey);
      if (raw == null) {
        return [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded.whereType<String>().toList();
    }
    catch (e) {
      return [];
    }
  }

  Future<void> _save() async {
    await _sharedPreferences.setString(_dockAppsKey, jsonEncode(_packageNames));
  }
}