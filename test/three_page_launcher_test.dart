import 'package:flauncher/flauncher.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/widgets/all_apps_grid.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_container_common.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'mocks.dart';

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

  testWidgets("Page 1 shows the favorites category as a bottom row with an add-app card", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    final favoritesCategory = fakeCategory(name: "Favorites", order: 0);
    favoritesCategory.applications.add(app);
    when(appsService.favoritesCategory).thenReturn(favoritesCategory);

    await pumpLauncher(tester, appsService);

    expect(find.byType(CategoryRow), findsOneWidget);
    expect(find.byType(AppsGrid), findsNothing);
    expect(find.byType(AddAppCard), findsOneWidget);
    expect(find.byType(AlternativeLauncherView), findsNothing);
  });

  testWidgets("Arrow down at the page edge skips the blank categories page", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(packageName: "me.efesser.flauncher.1", name: "FLauncher 1");
    final favoritesCategory = fakeCategory(name: "Favorites", order: 0);
    favoritesCategory.applications.add(app);
    when(appsService.favoritesCategory).thenReturn(favoritesCategory);
    when(appsService.launcherSections).thenReturn([]);

    await pumpLauncher(tester, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryRow), findsNothing);
    final context = tester.element(find.byType(FLauncher));
    expect(context.read<LauncherState>().currentPage, LauncherState.allAppsPage);
  });

  testWidgets("Back navigation walks the pages backwards", (tester) async {
    final appsService = mkAppService();
    when(appsService.favoritesCategory).thenReturn(fakeCategory(name: "Favorites", order: 0));
    when(appsService.launcherSections).thenReturn([]);

    await pumpLauncher(tester, appsService);

    final context = tester.element(find.byType(FLauncher));
    final launcherState = context.read<LauncherState>();
    launcherState.showPage(LauncherState.allAppsPage);
    await tester.pumpAndSettle();
    expect(find.byType(AllAppsGrid), findsOneWidget);
    expect(find.byType(CategoryRow), findsNothing);

    // Same code path as PopScope.onPopInvoked. The blank categories page is
    // skipped when there are no custom sections.
    launcherState.handleBackNavigation(context);
    await tester.pumpAndSettle();
    expect(launcherState.currentPage, LauncherState.favoritesPage);
    expect(find.byType(CategoryRow), findsOneWidget);
  });

  testWidgets("Back navigation on the favorites page keeps the launcher visible", (tester) async {
    final appsService = mkAppService();
    when(appsService.favoritesCategory).thenReturn(fakeCategory(name: "Favorites", order: 0));

    await pumpLauncher(tester, appsService);

    final context = tester.element(find.byType(FLauncher));
    final launcherState = context.read<LauncherState>();

    launcherState.handleBackNavigation(context);

    expect(launcherState.currentPage, LauncherState.favoritesPage);
    expect(launcherState.launcherVisible, isTrue);
  });

  test("nextPage and previousPage clamp to the three pages", () {
    final launcherState = LauncherState();

    launcherState.previousPage();
    expect(launcherState.currentPage, LauncherState.favoritesPage);

    launcherState.nextPage();
    expect(launcherState.currentPage, LauncherState.categoriesPage);

    launcherState.nextPage();
    expect(launcherState.currentPage, LauncherState.allAppsPage);

    launcherState.nextPage();
    expect(launcherState.currentPage, LauncherState.allAppsPage);

    launcherState.previousPage();
    expect(launcherState.currentPage, LauncherState.categoriesPage);
  });
}