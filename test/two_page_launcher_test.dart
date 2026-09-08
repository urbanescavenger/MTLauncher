import 'dart:convert';

import 'package:flauncher/flauncher.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/dock_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/dock_bar.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets("Page 1 shows clock and dock, not the app sections", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    when(appsService.getApplication("me.efesser.flauncher.1")).thenReturn(app);
    final dockService = await mkDockService(["me.efesser.flauncher.1"]);

    await _pumpLauncher(tester, appsService, dockService);

    expect(find.byType(AlternativeLauncherView), findsOneWidget);
    expect(find.byType(DockBar), findsOneWidget);
  });

  testWidgets("Arrow down from dock page switches to apps page", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    when(appsService.getApplication("me.efesser.flauncher.1")).thenReturn(app);
    final dockService = await mkDockService(["me.efesser.flauncher.1"]);

    await _pumpLauncher(tester, appsService, dockService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byType(DockBar), findsNothing);
    final context = tester.element(find.byType(FLauncher));
    expect(context.read<LauncherState>().currentPage, LauncherState.appsPage);
  });

  testWidgets("Back navigation from apps page returns to dock page", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    when(appsService.getApplication("me.efesser.flauncher.1")).thenReturn(app);
    final dockService = await mkDockService(["me.efesser.flauncher.1"]);

    await _pumpLauncher(tester, appsService, dockService);

    final context = tester.element(find.byType(FLauncher));
    final launcherState = context.read<LauncherState>();
    launcherState.showAppsPage();
    await tester.pumpAndSettle();
    expect(find.byType(DockBar), findsNothing);

    // Same code path as PopScope.onPopInvoked
    launcherState.handleBackNavigation(context);
    await tester.pumpAndSettle();

    expect(launcherState.currentPage, LauncherState.dockPage);
    expect(find.byType(DockBar), findsOneWidget);
  });

  testWidgets("Back navigation on dock page keeps dock page", (tester) async {
    final appsService = mkAppService();
    final dockService = await mkDockService([]);

    await _pumpLauncher(tester, appsService, dockService);

    final context = tester.element(find.byType(FLauncher));
    final launcherState = context.read<LauncherState>();

    launcherState.handleBackNavigation(context);

    expect(launcherState.currentPage, LauncherState.dockPage);
    expect(launcherState.launcherVisible, isTrue);
  });
}

Future<DockService> mkDockService(List<String> pinned) async {
  SharedPreferences.setMockInitialValues({"dock_apps": jsonEncode(pinned)});
  return DockService(await SharedPreferences.getInstance());
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
  when(settingsService.backButtonAction).thenReturn(BACK_BUTTON_ACTION_NOTHING);
  return settingsService;
}

WallpaperService mkWallpaperService() {
  final wallpaperService = MockWallpaperService();
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  when(wallpaperService.wallpaper).thenReturn(null);
  return wallpaperService;
}

AppsService mkAppService() {
  final appsService = MockAppsService();
  when(appsService.initialized).thenReturn(true);
  when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
  return appsService;
}

Future<void> _pumpLauncher(
  WidgetTester tester,
  AppsService appsService,
  DockService dockService,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WallpaperService>.value(value: mkWallpaperService()),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: mkSettingsService()),
        ChangeNotifierProvider(create: (_) => LauncherState()),
        ChangeNotifierProvider<DockService>.value(value: dockService),
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