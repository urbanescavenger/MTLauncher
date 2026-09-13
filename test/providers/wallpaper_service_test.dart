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

import 'package:drift/drift.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../mocks.mocks.dart';

void main() {
  late final _MockPathProviderPlatform pathProviderPlatform;
  setUpAll(() {
    pathProviderPlatform = _MockPathProviderPlatform();
    when(pathProviderPlatform.getApplicationDocumentsPath()).thenAnswer((_) => Future.value("."));
    PathProviderPlatform.instance = pathProviderPlatform;
  });

  group("pickWallpaper", () {
    test("picks image", () async {
      final fLauncherChannel = MockFLauncherChannel();
      final settingsService = MockSettingsService();
      when(fLauncherChannel.pickImageBytes()).thenAnswer((_) => Future.value(Uint8List.fromList([0x01])));
      when(fLauncherChannel.checkForGetContentAvailability()).thenAnswer((_) => Future.value(true));
      final wallpaperService = WallpaperService(fLauncherChannel, settingsService);
      await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

      await wallpaperService.pickWallpaper();

      expect(wallpaperService.wallpaper.hashCode, 1);
    });

    test("keeps existing wallpaper when picker returns no image", () async {
      final fLauncherChannel = MockFLauncherChannel();
      final settingsService = MockSettingsService();
      when(fLauncherChannel.pickImageBytes()).thenAnswer((_) => Future.value(null));
      when(fLauncherChannel.checkForGetContentAvailability()).thenAnswer((_) => Future.value(true));
      final wallpaperService = WallpaperService(fLauncherChannel, settingsService);
      await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

      await wallpaperService.pickWallpaper();

      expect(wallpaperService.wallpaper, null);
    });

    test("throws error when no file explorer installed", () async {
      final fLauncherChannel = MockFLauncherChannel();
      when(fLauncherChannel.checkForGetContentAvailability()).thenAnswer((_) => Future.value(false));
      final wallpaperService = WallpaperService(fLauncherChannel, MockSettingsService());
      await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

      expect(() async => await wallpaperService.pickWallpaper(), throwsA(isInstanceOf<NoFileExplorerException>()));
    });
  });


  test("setGradient", () async {
    final fLauncherChannel = MockFLauncherChannel();
    final settingsService = MockSettingsService();
    final wallpaperService = WallpaperService(fLauncherChannel, settingsService);

    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await wallpaperService.setGradient(FLauncherGradients.greatWhale);

    verify(settingsService.setGradientUuid(FLauncherGradients.greatWhale.uuid));
    expect(wallpaperService.wallpaper, null);
  });

  group("getGradient", () {
    test("without uuid from settings", () async {
      final fLauncherChannel = MockFLauncherChannel();
      final settingsService = MockSettingsService();
      final wallpaperService = WallpaperService(fLauncherChannel, settingsService);
      when(settingsService.gradientUuid).thenReturn(null);

      await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
      final gradient = wallpaperService.gradient;

      expect(gradient, FLauncherGradients.greatWhale);
    });

    test("with uuid from settings", () async {
      final fLauncherChannel = MockFLauncherChannel();
      final settingsService = MockSettingsService();
      final wallpaperService = WallpaperService(fLauncherChannel, settingsService);
      when(settingsService.gradientUuid).thenReturn(FLauncherGradients.grassShampoo.uuid);
      await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

      final gradient = wallpaperService.gradient;

      expect(gradient, FLauncherGradients.grassShampoo);
    });
  });
}

class _MockPathProviderPlatform extends Mock with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() =>
      super.noSuchMethod(Invocation.method(#getApplicationDocumentsPath, []), returnValue: Future<String?>.value());
}
