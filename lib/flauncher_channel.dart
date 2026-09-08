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

import 'package:flutter/services.dart';

class FLauncherChannel {
  static const _methodChannel = MethodChannel('me.efesser.flauncher/method');
  static const _appsEventChannel = EventChannel('me.efesser.flauncher/event_apps');
  static const _networkEventChannel = EventChannel('me.efesser.flauncher/event_network');

  Future<List<Map<dynamic, dynamic>>> getApplications() async {
    List<Map<dynamic, dynamic>>? applications = await _methodChannel.invokeListMethod("getApplications");
    return applications!;
  }

  Future<Uint8List> getApplicationBanner(String packageName) async {
    Uint8List bytes = await _methodChannel.invokeMethod("getApplicationBanner", packageName);
    return bytes;
  }

  Future<Uint8List> getApplicationIcon(String packageName) async {
    Uint8List bytes = await _methodChannel.invokeMethod("getApplicationIcon", packageName);
    return bytes;
  }

  Future<bool> applicationExists(String packageName) async =>
      await _methodChannel.invokeMethod('applicationExists', packageName);

  Future<void> launchActivityFromAction(String action) async => await _methodChannel.invokeMethod('launchActivityFromAction', action);

  Future<void> launchApp(String packageName) async => await _methodChannel.invokeMethod('launchApp', packageName);

  Future<void> openSettings() async => await _methodChannel.invokeMethod('openSettings');

  Future<void> openAppInfo(String packageName) async => await _methodChannel.invokeMethod('openAppInfo', packageName);

  Future<void> uninstallApp(String packageName) async => await _methodChannel.invokeMethod('uninstallApp', packageName);

  Future<bool> isDefaultLauncher() async => await _methodChannel.invokeMethod('isDefaultLauncher');

  Future<bool> installApk(String path) async => await _methodChannel.invokeMethod('installApk', path);

  Future<bool> canInstallPackages() async => await _methodChannel.invokeMethod('canInstallPackages');

  Future<bool> openUnknownSourcesSettings() async => await _methodChannel.invokeMethod('openUnknownSourcesSettings');

  Future<bool> checkForGetContentAvailability() async =>
      await _methodChannel.invokeMethod("checkForGetContentAvailability");

  Future<Map<String, dynamic>> getActiveNetworkInformation() async {
    Map<dynamic, dynamic> map = await _methodChannel.invokeMethod("getActiveNetworkInformation");
    return map.cast<String, dynamic>();
  }

  Future<List<String>> getSupportedAbis() async {
    List<dynamic>? abis = await _methodChannel.invokeListMethod("getSupportedAbis");
    return abis!.cast<String>();
  }

  Future<MemoryInfo> getMemoryInfo() async {
    Map<dynamic, dynamic> map = await _methodChannel.invokeMethod("getMemoryInfo");
    return MemoryInfo(map["total"] as int, map["avail"] as int);
  }

  Future<CleanMemoryResult> cleanMemory() async {
    Map<dynamic, dynamic> map = await _methodChannel.invokeMethod("cleanMemory");
    return CleanMemoryResult(map["freed"] as int, map["avail"] as int);
  }

  Future<void> startAmbientMode() async => await _methodChannel.invokeMethod("startAmbientMode");

  void addAppsChangedListener(void Function(Map<String, dynamic>) listener) =>
      _appsEventChannel.receiveBroadcastStream().listen((event) {
        Map<dynamic, dynamic> eventMap = event;
        listener(eventMap.cast<String, dynamic>());
      });

  void addNetworkChangedListener(void Function(Map<String, dynamic>) listener) =>
      _networkEventChannel.receiveBroadcastStream().listen((event) {
        Map<dynamic, dynamic> eventMap = event;
        listener(eventMap.cast<String, dynamic>());
      });
}

class MemoryInfo
{
  final int totalMem;
  final int availMem;

  MemoryInfo(this.totalMem, this.availMem);
}

class CleanMemoryResult
{
  final int freed;
  final int availMem;

  CleanMemoryResult(this.freed, this.availMem);
}
