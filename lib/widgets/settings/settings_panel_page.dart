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

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/update_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/date_time_format_dialog.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../rounded_switch_list_tile.dart';
import 'back_button_actions.dart';

class SettingsPanelPage extends StatelessWidget {
  static const String routeName = "settings_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, settingsService, __) => Column(
        children: [
          Text(localizations.settings, style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  EnsureVisible(
                    alignment: 0.5,
                    child: TextButton(
                      autofocus: true,
                      child: Row(
                        children: [
                          const Icon(Icons.apps),
                          Container(width: 8),
                          Text(localizations.applications, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      onPressed: () => Navigator.of(context).pushNamed(ApplicationsPanelPage.routeName),
                    ),
                  ),
                  TextButton(
                    child: Row(
                      children: [
                        const Icon(Icons.category),
                        Container(width: 8),
                        Text(localizations.launcherSections, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () => Navigator.of(context).pushNamed(LauncherSectionsPanelPage.routeName),
                  ),
                  TextButton(
                    child: Row(
                      children: [
                        const Icon(Icons.wallpaper_outlined),
                        Container(width: 8),
                        Text(localizations.wallpaper, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () => Navigator.of(context).pushNamed(WallpaperPanelPage.routeName),
                  ),
                  TextButton(
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates),
                        Container(width: 8),
                        Text(localizations.statusBar, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () => Navigator.of(context).pushNamed(StatusBarPanelPage.routeName),
                  ),
                  const Divider(),
                  TextButton(
                    child: Row(
                      children: [
                        const Icon(Icons.settings_outlined),
                        Container(width: 8),
                        Text(localizations.systemSettings, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () => context.read<AppsService>().openSettings(),
                  ),
                  const Divider(),
                  TextButton(
                    child: Row(
                      children: [
                        const Icon(Icons.date_range),
                        Container(width: 8),
                        Text(localizations.dateAndTimeFormat, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () async => await _dateTimeFormatDialog(context),
                  ),
                  TextButton(
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back),
                        Container(width: 8),
                        Text(localizations.backButtonAction, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () async => await _backButtonActionDialog(context),
                  ),
                  TextButton(
                    child: Row(
                      children: [
                        const Icon(Icons.language),
                        Container(width: 8),
                        Text(localizations.language, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () async => await _languageDialog(context),
                  ),
                  RoundedSwitchListTile(
                    value: settingsService.appHighlightAnimationEnabled,
                    onChanged: (value) => settingsService.setAppHighlightAnimationEnabled(value),
                    title: Text(localizations.appCardHighlightAnimation, style: Theme.of(context).textTheme.bodyMedium),
                    secondary: Icon(Icons.filter_center_focus),
                  ),
                  RoundedSwitchListTile(
                    value: settingsService.appKeyClickEnabled,
                    onChanged: (value) => settingsService.setAppKeyClickEnabled(value),
                    title: Text(localizations.appKeyClick, style: Theme.of(context).textTheme.bodyMedium),
                    secondary: Icon(Icons.notifications_active),
                  ),
                  RoundedSwitchListTile(
                      value: settingsService.showCategoryTitles,
                      onChanged: (value) => settingsService.setShowCategoryTitles(value),
                      title: Text(localizations.showCategoryTitles, style: Theme.of(context).textTheme.bodyMedium),
                      secondary: Icon(Icons.abc)
                  ),
                  const Divider(),
                  Consumer<UpdateService>(
                    builder: (context, updateService, __) => TextButton(
                      onPressed: updateService.status == UpdateStatus.downloading
                          || updateService.status == UpdateStatus.checking
                          ? null
                          : () => _onUpdatePressed(context),
                      child: Row(
                        children: [
                          const Icon(Icons.system_update),
                          Container(width: 8),
                          Flexible(child: Text(
                            _updateButtonLabel(context, updateService),
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          )),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline),
                        Container(width: 8),
                        Text(localizations.aboutFlauncher, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done
                            ? FLauncherAboutDialog(packageInfo: snapshot.data!)
                            : Container(),
                      )
                    )
                  )
                ]
              )
            )
          )
        ]
      )
    );
  }

  void _onUpdatePressed(BuildContext context) {
    UpdateService updateService = context.read<UpdateService>();

    if (updateService.status == UpdateStatus.available) {
      updateService.download();
    }
    else if (updateService.status == UpdateStatus.downloaded) {
      updateService.install().then((installed) {
        if (!installed && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.allowUnknownSourcesFirst),
          ));
        }
      });
    }
    else {
      updateService.check();
    }
  }

  String _updateButtonLabel(BuildContext context, UpdateService updateService) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    UpdateStatus status = updateService.status;

    if (status == UpdateStatus.checking) {
      return localizations.updateChecking;
    }
    else if (status == UpdateStatus.available) {
      return localizations.updateAvailableTo(updateService.updateInfo!.version);
    }
    else if (status == UpdateStatus.downloading) {
      int total = updateService.updateInfo?.size ?? 0;
      String progress = total > 0
          ? "${updateService.receivedBytes * 100 ~/ total}%"
          : "${updateService.receivedBytes}";
      return localizations.updateDownloading(progress);
    }
    else if (status == UpdateStatus.downloaded) {
      return localizations.updateReadyToInstall;
    }
    else if (status == UpdateStatus.upToDate) {
      return localizations.appUpToDate;
    }
    else if (status == UpdateStatus.failed) {
      return localizations.updateCheckFailed;
    }
    else {
      return localizations.checkForUpdates;
    }
  }

  Future<void> _languageDialog(BuildContext context) async {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService service = context.read<SettingsService>();

    final newLocale = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
            title: Text(localizations.language),
            children: [
              SimpleDialogOption(
                child: Text(localizations.systemDefault),
                onPressed: () => Navigator.pop(dialogContext, ""),
              ),
              SimpleDialogOption(
                child: const Text("English"),
                onPressed: () => Navigator.pop(dialogContext, "en"),
              ),
              SimpleDialogOption(
                child: const Text("Español"),
                onPressed: () => Navigator.pop(dialogContext, "es"),
              ),
              SimpleDialogOption(
                child: const Text("中文"),
                onPressed: () => Navigator.pop(dialogContext, "zh"),
              ),
            ]
        )
    );

    if (newLocale != null) {
      await service.setLocale(newLocale.isEmpty ? null : newLocale);
      // The favorites category name is stored in the database; rewrite it so
      // it follows the new language instead of waiting for the next startup.
      await context.read<AppsService>().refreshFavoritesCategoryName();
    }
  }

  Future<void> _backButtonActionDialog(BuildContext context) async {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService service = context.read<SettingsService>();

    final newAction = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
            title: Text(localizations.dialogTitleBackButtonAction),
            children: [
              SimpleDialogOption(
                child: Text(localizations.dialogOptionBackButtonActionDoNothing),
                onPressed: () => Navigator.pop(context, ""),
              ),
              SimpleDialogOption(
                child: Text(localizations.dialogOptionBackButtonActionShowClock),
                onPressed: () => Navigator.pop(context, BACK_BUTTON_ACTION_CLOCK),
              ),
              SimpleDialogOption(
                child: Text(localizations.dialogOptionBackButtonActionShowScreensaver),
                onPressed: () => Navigator.pop(context, BACK_BUTTON_ACTION_SCREENSAVER),
              )
            ]
        )
    );

    if (newAction != null) {
      await service.setBackButtonAction(newAction);
    }
  }

  Future<void> _dateTimeFormatDialog(BuildContext context) async {
    SettingsService service = context.read<SettingsService>();

    final formatTuple = await showDialog<Tuple2<String, String>>(
        context: context,
        builder: (_) => DateTimeFormatDialog(service.dateFormat, service.timeFormat)
    );

    if (formatTuple != null) {
      await service.setDateTimeFormat(formatTuple.item1, formatTuple.item2);
    }
  }
}
