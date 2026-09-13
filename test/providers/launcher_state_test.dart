import 'package:flauncher/providers/launcher_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("handleHomeKey", () {
    test("returns to the favorites page from any other page", () {
      LauncherState state = LauncherState();
      state.showPage(LauncherState.allAppsPage);

      state.handleHomeKey();

      expect(state.currentPage, LauncherState.favoritesPage);
      expect(state.launcherVisible, isTrue);
    });

    test("leaves the alternative clock view", () {
      LauncherState state = LauncherState();
      state.toggleLauncherVisibility();

      state.handleHomeKey();

      expect(state.launcherVisible, isTrue);
      expect(state.currentPage, LauncherState.favoritesPage);
    });

    test("is a no-op when already on the favorites page", () {
      LauncherState state = LauncherState();
      bool notified = false;
      state.addListener(() => notified = true);

      state.handleHomeKey();

      expect(notified, isFalse);
    });
  });
}