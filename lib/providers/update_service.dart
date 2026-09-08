/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
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
import 'dart:io';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const _repoOwner = "urbanescavenger";
const _repoName = "MTLauncher";
const _debugAssetName = "MTlauncher-debug.apk";
const _releaseAssetName = "MTlauncher-universal-release.apk";
const _downloadFileName = "MTlauncher-update.apk";

enum UpdateStatus { idle, checking, upToDate, available, downloading, downloaded, failed }

@immutable
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final int size;

  const UpdateInfo(this.version, this.downloadUrl, this.size);
}

class UpdateService extends ChangeNotifier {
  final FLauncherChannel _channel;
  final http.Client _client = http.Client();

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _updateInfo;
  int _receivedBytes = 0;
  String? _errorMessage;
  String? _downloadedPath;
  bool _busy = false;

  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  int get receivedBytes => _receivedBytes;
  String? get errorMessage => _errorMessage;

  UpdateService(this._channel);

  Future<void> check() async {
    if (_busy) return;
    _busy = true;
    _errorMessage = null;
    _status = UpdateStatus.checking;
    notifyListeners();

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      if (kDebugMode) {
        final release = await _checkDebugRelease();
        final installed = int.tryParse(packageInfo.buildNumber) ?? 0;

        if (release.versionCode > installed) {
          _updateInfo = UpdateInfo(release.versionName, release.downloadUrl, release.assetSize);
          _status = UpdateStatus.available;
        }
        else {
          _status = UpdateStatus.upToDate;
        }
      }
      else {
        // 稳定版用户只收稳定版;版本名带 "-"(如 1.0.0-alpha.1)的用户可以收到预发布更新。
        final release = await _checkLatestRelease(packageInfo.version);
        final installedVersionCode = versionCodeFromVersionName(packageInfo.version) ?? 0;

        // 旧月度版本(YYYY.MM.NNN)在新语义版本之前,视为已过期,直接提示更新。
        final isLegacyMonthlyVersion = RegExp(r"^\d{4}\.\d{2}\.\d{3}$").hasMatch(packageInfo.version);

        if (release.versionCode > installedVersionCode || isLegacyMonthlyVersion) {
          _updateInfo = UpdateInfo(release.versionName, release.downloadUrl, release.assetSize);
          _status = UpdateStatus.available;
        }
        else {
          _status = UpdateStatus.upToDate;
        }
      }
    }
    catch (e) {
      _errorMessage = e.toString();
      _status = UpdateStatus.failed;
    }
    finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> download() async {
    if (_busy || _updateInfo == null) return;
    _busy = true;
    _errorMessage = null;
    _status = UpdateStatus.downloading;
    _receivedBytes = 0;
    notifyListeners();

    try {
      final directory = Directory("${(await getApplicationCacheDirectory()).path}/updates");
      await directory.create(recursive: true);
      final file = File("${directory.path}/$_downloadFileName");
      final tempFile = File("${file.path}.tmp");

      final response = await _client.send(http.Request("GET", Uri.parse(_updateInfo!.downloadUrl)));
      if (response.statusCode != 200) {
        throw Exception("Download failed with HTTP ${response.statusCode}");
      }

      final sink = tempFile.openSync(mode: FileMode.write);
      try {
        var received = 0;
        await for (final chunk in response.stream) {
          sink.writeFromSync(chunk);
          received += chunk.length;
          _receivedBytes = received;
          notifyListeners();
        }
      }
      finally {
        sink.closeSync();
      }

      if (tempFile.lengthSync() != _updateInfo!.size) {
        tempFile.deleteSync();
        throw Exception("Downloaded file size mismatch");
      }

      tempFile.renameSync(file.path);
      _downloadedPath = file.path;
      _status = UpdateStatus.downloaded;
    }
    catch (e) {
      _errorMessage = e.toString();
      _status = UpdateStatus.failed;
    }
    finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Returns true if the system installer was started, false if the user was
  /// redirected to the "install unknown apps" system settings page instead.
  Future<bool> install() async {
    if (_downloadedPath == null) return false;

    if (!await _channel.canInstallPackages()) {
      await _channel.openUnknownSourcesSettings();
      return false;
    }

    final installed = await _channel.installApk(_downloadedPath!);

    if (installed) {
      _status = UpdateStatus.idle;
      _updateInfo = null;
      notifyListeners();
    }

    return installed;
  }

  Future<_RemoteRelease> _checkLatestRelease(String installedVersionName) async {
    final body = await _getJson("https://api.github.com/repos/$_repoOwner/$_repoName/releases?per_page=30");
    final releases = body as List? ?? [];
    final includePrereleases = installedVersionName.contains("-");

    _RemoteRelease? best;

    for (final release in releases.cast<Map<String, dynamic>>()) {
      if (release["draft"] == true) continue;
      if (!includePrereleases && release["prerelease"] == true) continue;

      final tagName = release["tag_name"] as String? ?? "";
      final versionName = tagName.startsWith("v") ? tagName.substring(1) : tagName;
      final versionCode = versionCodeFromVersionName(versionName);

      if (versionCode == null) continue;
      if (best != null && versionCode <= best.versionCode) continue;

      final asset = _asset(release, _releaseAssetName);

      best = _RemoteRelease(
          versionName,
          versionCode,
          asset["browser_download_url"] as String,
          asset["size"] as int);
    }

    if (best == null) {
      throw Exception("No eligible releases found");
    }

    return best;
  }

  Future<_RemoteRelease> _checkDebugRelease() async {
    final body = await _getJson("https://api.github.com/repos/$_repoOwner/$_repoName/releases/tags/debug");
    final notes = body["body"] as String? ?? "";

    final versionCodeMatch = RegExp(r"versionCode=(\d+)").firstMatch(notes);
    if (versionCodeMatch == null) {
      throw Exception("Debug release notes missing versionCode");
    }

    final versionName = RegExp(r"versionName=(\S+)").firstMatch(notes)?.group(1) ?? "dev";
    final asset = _asset(body, _debugAssetName);

    return _RemoteRelease(
        versionName,
        int.parse(versionCodeMatch.group(1)!),
        asset["browser_download_url"] as String,
        asset["size"] as int);
  }

  Map<String, dynamic> _asset(Map<String, dynamic> release, String name) {
    final assets = (release["assets"] as List? ?? []).cast<Map<String, dynamic>>();

    return assets.firstWhere(
        (asset) => asset["name"] == name,
        orElse: () => throw Exception("Release asset not found: $name"));
  }

  Future<dynamic> _getJson(String url) async {
    final response = await _get(url);

    if (response.statusCode != 200) {
      throw Exception("GitHub API returned HTTP ${response.statusCode}");
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<http.Response> _get(String url) async {
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await _client.get(Uri.parse(url), headers: {
          "Accept": "application/vnd.github+json",
          "User-Agent": "MTLauncher-Android",
        });

        if (response.statusCode < 500) {
          return response;
        }

        lastError = Exception("GitHub API returned HTTP ${response.statusCode}");
      }
      catch (e) {
        lastError = e;
      }

      await Future.delayed(Duration(milliseconds: 800 * attempt));
    }

    throw lastError ?? Exception("Request failed");
  }
}

class _RemoteRelease {
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final int assetSize;

  const _RemoteRelease(this.versionName, this.versionCode, this.downloadUrl, this.assetSize);
}

/// 把语义版本名解析成可比较的 versionCode,权重与 CI 端算法严格一致
/// (见 .github/workflows/continuous-release.yml):
/// major*1000000 + minor*100000 + patch*1000 + label(alpha=1,beta=2,rc=3)*100 + 序号。
/// 版本名不符合语义版本格式(如旧月度版本以外的异常值)时返回 null。
int? versionCodeFromVersionName(String versionName) {
  final match = RegExp(r"^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z]+)\.(\d+))?$")
      .firstMatch(versionName);

  if (match == null) {
    return null;
  }

  final label = match.group(4)?.toLowerCase();
  final labelOrder = label == "alpha" ? 1 : label == "beta" ? 2 : label == "rc" ? 3 : 0;

  return int.parse(match.group(1)!) * 1000000
      + int.parse(match.group(2)!) * 100000
      + int.parse(match.group(3)!) * 1000
      + labelOrder * 100
      + (int.tryParse(match.group(5) ?? "0") ?? 0);
}