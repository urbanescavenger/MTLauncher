import 'dart:convert';

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/dock_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/dock_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

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

  testWidgets("DockBar shows empty-state hint when nothing is pinned", (tester) async {
    final appsService = mkAppService();
    final dockService = await mkDockService([]);

    await _pumpDockBar(tester, appsService, dockService);

    expect(find.text("No pinned apps. Long-press an app and select \"Pin to dock\"."), findsOneWidget);
  });

  testWidgets("DockBar renders pinned apps as dock cards", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    when(appsService.getApplication("me.efesser.flauncher.1")).thenReturn(app);
    final dockService = await mkDockService(["me.efesser.flauncher.1"]);

    await _pumpDockBar(tester, appsService, dockService);

    expect(find.byKey(Key("me.efesser.flauncher.1")), findsOneWidget);
  });

  testWidgets("DockBar filters apps that no longer exist", (tester) async {
    final appsService = mkAppService();
    // getApplication returns null by default for uninstalled apps
    final dockService = await mkDockService(["me.efesser.uninstalled"]);

    await _pumpDockBar(tester, appsService, dockService);

    expect(find.text("No pinned apps. Long-press an app and select \"Pin to dock\"."), findsOneWidget);
  });

  testWidgets("Pressing select on dock card launches app", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    when(appsService.getApplication("me.efesser.flauncher.1")).thenReturn(app);
    final dockService = await mkDockService(["me.efesser.flauncher.1"]);

    await _pumpDockBar(tester, appsService, dockService);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    verify(appsService.launchApp(app));
  });

  testWidgets("Long-press opens panel with unpin action and toggling unpins", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    when(appsService.getApplication("me.efesser.flauncher.1")).thenReturn(app);
    final dockService = await mkDockService(["me.efesser.flauncher.1"]);

    await _pumpDockBar(tester, appsService, dockService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher.1")));
    await tester.pumpAndSettle();

    expect(find.byType(ApplicationInfoPanel), findsOneWidget);
    expect(find.text("Unpin from dock"), findsOneWidget);

    await tester.tap(find.text("Unpin from dock"));
    await tester.pumpAndSettle();

    expect(find.text("Pin to dock"), findsOneWidget);
    expect(dockService.packageNames, isEmpty);
  });

  testWidgets("Panel reorder action enables move mode and reorders dock", (tester) async {
    final appsService = mkAppService();
    final app1 = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    final app2 = fakeApp(packageName: "me.efesser.flauncher.2", name: "FLauncher 2");
    when(appsService.getApplication("me.efesser.flauncher.1")).thenReturn(app1);
    when(appsService.getApplication("me.efesser.flauncher.2")).thenReturn(app2);
    final dockService = await mkDockService(["me.efesser.flauncher.1", "me.efesser.flauncher.2"]);

    await _pumpDockBar(tester, appsService, dockService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher.1")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Reorder"));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(dockService.packageNames, ["me.efesser.flauncher.2", "me.efesser.flauncher.1"]);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    // saveOrder persists the new order
    final reloaded = DockService(await SharedPreferences.getInstance());
    expect(reloaded.packageNames, ["me.efesser.flauncher.2", "me.efesser.flauncher.1"]);
  });
}

Future<DockService> mkDockService(List<String> pinned) async {
  SharedPreferences.setMockInitialValues({"dock_apps": jsonEncode(pinned)});
  final dockService = DockService(await SharedPreferences.getInstance());
  return dockService;
}

SettingsService mkSettingsService() {
  final settingsService = MockSettingsService();
  when(settingsService.dateFormat).thenReturn(SettingsService.defaultDateFormat);
  when(settingsService.timeFormat).thenReturn(SettingsService.defaultTimeFormat);
  when(settingsService.appHighlightAnimationEnabled).thenReturn(true);
  return settingsService;
}

AppsService mkAppService() {
  final appsService = MockAppsService();
  when(appsService.initialized).thenReturn(true);
  return appsService;
}

Future<void> _pumpDockBar(
  WidgetTester tester,
  AppsService appsService,
  DockService dockService,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<DockService>.value(value: dockService),
        ChangeNotifierProvider<SettingsService>.value(value: mkSettingsService()),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DockBar()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}