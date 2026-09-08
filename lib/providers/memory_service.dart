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

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;

class MemoryService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;
  late final Timer _refreshTimer;

  /// Total device memory in bytes, 0 until the first successful read.
  int totalMem = 0;

  /// Currently available memory in bytes, 0 until the first successful read.
  int availMem = 0;

  /// Memory freed by the last clean in bytes, null before the first clean.
  int? lastFreed;

  bool get initialized => totalMem > 0;

  /// Percentage of memory that is available (0-100).
  int get availPercent => totalMem > 0 ? ((availMem / totalMem) * 100).round() : 0;

  bool _cleaning = false;
  bool get cleaning => _cleaning;

  MemoryService(this._fLauncherChannel) {
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final memoryInfo = await _fLauncherChannel.getMemoryInfo();
      totalMem = memoryInfo.totalMem;
      availMem = memoryInfo.availMem;
      notifyListeners();
    } on PlatformException {
      // Keep the last known values; the timer will retry.
    }
  }

  /// Kills background processes of third-party apps and returns the freed
  /// memory in bytes. The reported amount is always the real measured delta.
  Future<int> clean() async {
    if (_cleaning) {
      return 0;
    }

    _cleaning = true;
    notifyListeners();

    try {
      final result = await _fLauncherChannel.cleanMemory();
      availMem = result.availMem;
      lastFreed = result.freed;
      return result.freed;
    } on PlatformException {
      return 0;
    } finally {
      _cleaning = false;
      notifyListeners();
    }
  }
}