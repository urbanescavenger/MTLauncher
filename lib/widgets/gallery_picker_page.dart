/*
 * MTLauncher wallpaper gallery picker
 * Copyright (C) 2026
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

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// One image from the device gallery, loaded via MediaStore on the native side.
class GalleryImage {
  final int id;
  final Uint8List thumbnail;

  const GalleryImage({required this.id, required this.thumbnail});
}

/// What GalleryPickerPage pops its route with.
class GalleryPickerResult {
  final Uint8List? bytes;
  final bool browseFilesRequested;

  const GalleryPickerResult.picked(this.bytes) : browseFilesRequested = false;
  const GalleryPickerResult.browseFiles() : bytes = null, browseFilesRequested = true;
}

/// Full-screen in-app gallery browser. Exists because the system photo picker
/// and DocumentsUI ignore the D-pad on many TV boxes; here focus traversal is
/// the launcher's own, so the remote always works. Picking a tile resolves the
/// full image via [resolveImage] and pops the route with the bytes.
class GalleryPickerPage extends StatelessWidget {
  final List<GalleryImage> images;
  final Future<Uint8List?> Function(int id) resolveImage;

  const GalleryPickerPage({required this.images, required this.resolveImage});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Text(
                  localizations.galleryTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(localizations.galleryBrowseFiles, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () => Navigator.of(context).pop(const GalleryPickerResult.browseFiles()),
                ),
              ],
            ),
          ),
          Expanded(
            child: images.isEmpty
                ? Center(child: Text(localizations.galleryNoImages, style: Theme.of(context).textTheme.titleMedium))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      childAspectRatio: 1,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, index) => _GalleryTile(
                      image: images[index],
                      autofocus: index == 0,
                      resolveImage: resolveImage,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final GalleryImage image;
  final bool autofocus;
  final Future<Uint8List?> Function(int id) resolveImage;

  const _GalleryTile({required this.image, required this.autofocus, required this.resolveImage});

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: autofocus,
    child: Builder(
      builder: (context) {
        final focused = Focus.of(context).hasFocus;

        return InkWell(
          onTap: () async {
            final bytes = await resolveImage(image.id);
            if (bytes != null && context.mounted) {
              Navigator.of(context).pop(GalleryPickerResult.picked(bytes));
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.memory(image.thumbnail, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
        );
      },
    ),
  );
}