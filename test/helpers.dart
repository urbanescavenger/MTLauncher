import 'package:flauncher/flauncher.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/memory_service.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/update_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'mocks.mocks.dart';

Element? findAppCardByPackageName(WidgetTester tester, String packageName) {
  for (var val in tester.elementList(find.byType(AppCard))) {
    if ((val.widget as AppCard).application.packageName == packageName) {
      return val;
    }
  }
  return null;
}

Element? findSettingsIcon(WidgetTester tester) {
  // this function seems strange, but this is the simplest way I had to find the settings icon button
  for (var val in tester.elementList(find.byIcon(Icons.settings_outlined))) {
    if (((val as StatelessElement).widget as Icon).color == null) {
      return val;
    }
  }
  return null;
}

SettingsService mkSettingsService() {
  final settingsService = MockSettingsService();
  when(settingsService.dateFormat).thenReturn(SettingsService.defaultDateFormat);
  when(settingsService.timeFormat).thenReturn(SettingsService.defaultTimeFormat);
  when(settingsService.appHighlightAnimationEnabled).thenReturn(true);
  when(settingsService.showDateInStatusBar).thenReturn(true);
  when(settingsService.showTimeInStatusBar).thenReturn(true);
  when(settingsService.autoHideAppBarEnabled).thenReturn(false);
  when(settingsService.showCategoryTitles).thenReturn(true);
  when(settingsService.showMemoryInStatusBar).thenReturn(false);
  when(settingsService.backButtonAction).thenReturn(BACK_BUTTON_ACTION_NOTHING);
  return settingsService;
}

WallpaperService mkWallpaperService() {
  final wallpaperService = MockWallpaperService();
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  when(wallpaperService.wallpaper).thenReturn(null);
  return wallpaperService;
}

WeatherService mkWeatherService() {
  final weatherService = MockWeatherService();
  when(weatherService.enabled).thenReturn(false);
  when(weatherService.location).thenReturn(null);
  when(weatherService.currentWeather).thenReturn(null);
  return weatherService;
}

MemoryService mkMemoryService() {
  final memoryService = MockMemoryService();
  when(memoryService.cleaning).thenReturn(false);
  when(memoryService.initialized).thenReturn(false);
  return memoryService;
}

AppsService mkAppService() {
  final appsService = MockAppsService();
  when(appsService.initialized).thenReturn(true);
  when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
  when(appsService.applications).thenReturn([]);
  when(appsService.hasCustomSections).thenReturn(false);
  // The generated mock doesn't extend ChangeNotifier, so emulate its
  // listener bookkeeping: tests can then drive rebuilds via notifyListeners.
  final listeners = <VoidCallback>[];
  when(appsService.addListener(any)).thenAnswer((invocation) {
    listeners.add(invocation.positionalArguments.first as VoidCallback);
  });
  when(appsService.removeListener(any)).thenAnswer((invocation) {
    listeners.remove(invocation.positionalArguments.first as VoidCallback);
  });
  when(appsService.notifyListeners()).thenAnswer((_) {
    for (final listener in List.of(listeners)) {
      listener();
    }
  });
  return appsService;
}

Future<void> pumpLauncher(
  WidgetTester tester,
  AppsService appsService,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WallpaperService>.value(value: mkWallpaperService()),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: mkSettingsService()),
        ChangeNotifierProvider<WeatherService>.value(value: mkWeatherService()),
        ChangeNotifierProvider<MemoryService>.value(value: mkMemoryService()),
        ChangeNotifierProvider<UpdateService>.value(value: MockUpdateService()),
        ChangeNotifierProvider(create: (_) => LauncherState()),
        ChangeNotifierProvider(create: (_) => NetworkService(FLauncherChannel())),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FLauncher(),
      ),
    ),
  );
  await tester.pump(Duration(seconds: 30), EnginePhase.sendSemanticsUpdate);
}