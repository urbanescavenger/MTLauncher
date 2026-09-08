# MTLauncher

> **Fork notice:** This project is a fork of [FLauncher](https://gitlab.com/flauncher/flauncher), an open-source alternative launcher for Android TV built with [Flutter](https://flutter.dev). This fork is maintained at [urbanescavenger/MTLauncher](https://github.com/urbanescavenger/MTLauncher) and is rebranded as **MTLauncher**. For the full list of changes made in this fork, see the [CHANGELOG](CHANGELOG.md).
>
> 中文版:[README.md](README.md)

MTLauncher is a category-based launcher for Android TV: apps are grouped into customizable categories, browsable as horizontal rows or grids, with a favorites row pinned at the bottom of the home page.

## Download

- **Stable releases**: grab the latest APK from the [releases](https://github.com/urbanescavenger/MTLauncher/releases) page. Releases are cut from `v*` tags (e.g. `v1.0.0`); tags with a suffix such as `v1.0.0-alpha.1` are pre-releases.
- **Development builds**: every push to the `debug` branch is built by CI and published to a fixed [release tagged `debug`](https://github.com/urbanescavenger/MTLauncher/releases/download/debug/MTlauncher-debug.apk), overwriting the previous build. Expect rough edges.

The app has a built-in **update checker** (Settings → check for updates) that resolves the latest release, so installs can be upgraded in place from the launcher itself.

## Features

Fork-specific highlights:

- [x] Three-page launcher: home, categories, and an all-apps page
- [x] Favorites row pinned to the bottom of the home page, following the in-app language for its name
- [x] "Add app" card at the end of every section, including as a placeholder for empty ones
- [x] In-app language switcher (English / Spanish / 中文)
- [x] In-app update checker with version comparison, for both release and debug variants
- [x] FocusGuard: restores D-pad focus after it is lost (app startup, resume, page swaps)
- [x] Empty category pages are skipped when paging through

Inherited from upstream FLauncher:

- [x] No ads
- [x] Customizable categories
- [x] Manually reorder apps within categories
- [x] Wallpaper support
- [x] Open "Android Settings" / "App info"
- [x] Uninstall app
- [x] Clock and customizable date widget format
- [x] Switch between row and grid for categories
- [x] Support for non-TV (sideloaded) apps
- [x] Navigation sound feedback (can be disabled)
- [x] Back button actions: nothing / fullscreen clock / screensaver
- [ ] Force stop app

For the cumulative changes relative to the original FLauncher, see [CHANGELOG.md](CHANGELOG.md).

## Screenshots

|  |  |  |
|--|--|--|
| ![](screenshots/Screenshot_1624378896.png) | ![](screenshots/Screenshot_1624378921.png) | ![](screenshots/Screenshot_1624378938.png) |

## Set MTLauncher as default launcher

### Method 1: remap the Home button
This is the "safer" and easiest way. Use [Button Mapper](https://play.google.com/store/apps/details?id=flar2.homebutton) to remap the Home button of the remote to launch MTLauncher.

### Method 2: disable the default launcher
**:warning: Disclaimer :warning:**

**You are doing this at your own risk, and you'll be responsible in any case of malfunction on your device.**

The following commands have been tested on Chromecast with Google TV only. This may be different on other devices.

Once the default launcher is disabled, press the Home button on the remote, and you'll be prompted by the system to choose which app to set as default.

#### Disable default launcher
```shell
# Disable com.google.android.apps.tv.launcherx which is the default launcher on CCwGTV
$ adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
# com.google.android.tungsten.setupwraith will then be used as a 'fallback' and will automatically
# re-enable the default launcher, so disable it as well
$ adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
```

#### Re-enable default launcher
```shell
$ adb shell pm enable com.google.android.apps.tv.launcherx
$ adb shell pm enable com.google.android.tungsten.setupwraith
```

#### Known issues
On Chromecast with Google TV (maybe others), the "YouTube" remote button will stop working if the default launcher is disabled. As a workaround, you can use [Button Mapper](https://play.google.com/store/apps/details?id=flar2.homebutton) to remap it correctly.

## Wallpaper
Because Android's `WallpaperManager` is not available on some Android TV devices, MTLauncher implements its own wallpaper management method.

Please note that changing wallpaper requires a file explorer to be installed on the device in order to pick a file.

## Building
CI builds are the primary distribution channel (GitHub Actions, Flutter 3.24.5 + Java 17), but the project builds locally with a standard Flutter setup:

```shell
flutter pub get
flutter build apk --release
```

## Credits & license

- Original FLauncher by [etienn01](https://github.com/etienn01) ([GitLab](https://gitlab.com/flauncher/flauncher)) — consider [supporting the original author](https://www.buymeacoffee.com/etienn01).
- <a href="https://www.buymeacoffee.com/etienn01" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="200"></a>
- Licensed under [GPL-3.0](LICENSE), as the original project.