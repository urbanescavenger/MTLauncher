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

import 'dart:typed_data';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/gallery_picker_page.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class WallpaperPanelPage extends StatelessWidget {
  static const String routeName = "wallpaper_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
        children: [
          Text(localizations.wallpaper, style: Theme.of(context).textTheme.titleLarge),
          Divider(),
          TextButton(
            autofocus: true,
            child: Row(
              children: [
                Icon(Icons.gradient),
                Container(width: 8),
                Text(localizations.gradient, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            onPressed: () => Navigator.of(context).pushNamed(GradientPanelPage.routeName),
          ),
          TextButton(
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined),
                Container(width: 8),
                Text(localizations.picture, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            onPressed: () => _pickPicture(context),
          ),
        ],
      );
  }

  // 优先打开应用内相册浏览器(MediaStore;焦点遍历是 launcher 自己的,遥控器
  // 一定可用)。没有权限、设备没有图片,或用户点了"浏览文件"时,回落到系统
  // DocumentsUI 选文件(在部分盒子上 D-pad 不可用,所以只作为兜底)。
  Future<void> _pickPicture(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final fLauncherChannel = FLauncherChannel();
    final wallpaperService = context.read<WallpaperService>();

    Uint8List? bytes;

    try {
      if (!await fLauncherChannel.requestImageLibraryAccess()) {
        bytes = await _pickViaDocumentsUi(fLauncherChannel);
      }
      else {
        final rawImages = await fLauncherChannel.getGalleryImages();

        if (rawImages.isEmpty) {
          bytes = await _pickViaDocumentsUi(fLauncherChannel);
        }
        else {
          final images = rawImages
              .map((map) => GalleryImage(id: map["id"] as int, thumbnail: map["thumb"] as Uint8List))
              .toList();

          final result = await Navigator.of(context, rootNavigator: true).push<GalleryPickerResult>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => GalleryPickerPage(
                images: images,
                resolveImage: (id) => fLauncherChannel.getGalleryImageBytes(id),
              ),
            ),
          );

          if (result == null) {
            return; // 用户按返回键取消。
          }

          bytes = result.browseFilesRequested
              ? await _pickViaDocumentsUi(fLauncherChannel)
              : result.bytes;
        }
      }
    }
    on NoFileExplorerException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 8),
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(localizations.dialogTextNoFileExplorer)
            ],
          ),
        ),
      );
      return;
    }

    if (bytes != null) {
      await wallpaperService.setWallpaperBytes(bytes);
    }
  }

  Future<Uint8List?> _pickViaDocumentsUi(FLauncherChannel fLauncherChannel) async {
    if (!await fLauncherChannel.checkForGetContentAvailability()) {
      throw NoFileExplorerException();
    }

    return fLauncherChannel.pickImageBytes();
  }
}