// Reproduction test: removing an app from the favorites page leaves the
// D-pad focus dead, and pressing OK launches the removed app.
import 'package:flauncher/models/app.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
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

  testWidgets("Removing the focused app from favorites keeps D-pad focus alive", (tester) async {
    final appsService = mkAppService();
    final app1 = fakeApp(packageName: "app.1", name: "App One");
    final app2 = fakeApp(packageName: "app.2", name: "App Two");
    final favorites = fakeCategory(name: "Favorites", order: 0);
    favorites.applications.addAll([app1, app2]);
    when(appsService.favoritesCategory).thenReturn(favorites);
    when(appsService.launchApp(app2)).thenAnswer((_) async {});
    // Mimic the real AppsService.removeFromCategory: mutate the list, notify.
    when(appsService.removeFromCategory(app2, favorites)).thenAnswer((invocation) async {
      favorites.applications.remove(invocation.positionalArguments.first as App);
      appsService.notifyListeners();
    });

    await pumpLauncher(tester, appsService);

    // Autofocus is card 1; move to card 2. (No pumpAndSettle: the highlight
    // animation of a focused card repeats forever.)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_hasFocus(tester, "app.2"), isTrue, reason: "card 2 should be focused before opening the panel");

    // Long-press opens the app info panel.
    await tester.longPress(find.byType(AppCard).at(1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ApplicationInfoPanel), findsOneWidget);

    // Remove app 2 from favorites.
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ApplicationInfoPanel), findsNothing);
    expect(findAppCardByPackageName(tester, "app.2"), isNull, reason: "app 2 should be gone from the row");

    // D-pad must still work: focus should have landed on a live widget.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_hasFocus(tester, "app.1"), isTrue, reason: "focus should be usable after removal");

    // OK must not launch the removed app.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    verifyNever(appsService.launchApp(app2));
  });
}

bool _hasFocus(WidgetTester tester, String packageName) {
  final element = findAppCardByPackageName(tester, packageName);
  if (element == null) return false;
  final FocusNode node = Focus.of(element);
  final FocusNode? primary = FocusManager.instance.primaryFocus;
  return node.hasFocus && primary != null && (primary == node || node.traversalDescendants.contains(primary));
}