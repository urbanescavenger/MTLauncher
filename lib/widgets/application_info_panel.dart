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
import 'package:flauncher/widgets/add_to_category_dialog.dart';
import 'package:flauncher/widgets/right_panel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/app.dart';
import '../models/category.dart';

class ApplicationInfoPanel extends StatelessWidget
{
  final Category? category;
  final App application;
  final ImageProvider? applicationIcon;

  const ApplicationInfoPanel({
    this.category,
    required this.application,
    this.applicationIcon,
  });

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return RightPanelDialog(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (applicationIcon != null)
                  Image(image: applicationIcon!, width: 50)
                else
                  const Icon(Icons.image_not_supported_outlined),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    application.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              application.packageName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "v${application.version}",
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                 children: [
                   TextButton(
                     child: Row(
                       children: [
                         const Icon(Icons.open_in_new),
                         Container(width: 8),
                         Flexible(
                           child: Text(
                             localizations.open,
                             style: Theme.of(context).textTheme.bodyMedium,
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                       ],
                     ),
                     onPressed: () async {
                       await context.read<AppsService>().launchApp(application);
                       Navigator.of(context).pop(ApplicationInfoPanelResult.none);
                     },
                   ),
                   if (category?.sort == CategorySort.manual)
                     TextButton(
                       child: Row(
                         children: [
                           const Icon(Icons.open_with),
                           Container(width: 8),
                           Flexible(
                             child: Text(
                               localizations.reorder,
                               style: Theme.of(context).textTheme.bodyMedium,
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                       ),
                       onPressed: () => Navigator.of(context).pop(ApplicationInfoPanelResult.reorderApp),
                     ),
                   TextButton(
                     child: Row(
                       children: [
                         const Icon(Icons.add_box_outlined),
                         Container(width: 8),
                         Flexible(
                           child: Text(
                             localizations.withEllipsisAddTo,
                             style: Theme.of(context).textTheme.bodyMedium,
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                       ],
                     ),
                     onPressed: () => showDialog(
                       context: context,
                       builder: (_) => AddToCategoryDialog(application),
                     ),
                   ),
                   TextButton(
                     child: Row(
                       children: [
                         Icon(application.hidden ? Icons.visibility : Icons.visibility_off_outlined),
                         Container(width: 8),
                         Flexible(
                           child: Text(
                             application.hidden ? localizations.show : localizations.hide,
                             style: Theme.of(context).textTheme.bodyMedium,
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                       ],
                     ),
                     onPressed: () async {
                       // Close the panel before mutating: the removal
                       // rebuilds the row and can unmount the focused card,
                       // and popping afterwards would restore focus onto the
                       // now-stale node, leaving the D-pad dead.
                       final AppsService appsService = context.read<AppsService>();
                       Navigator.of(context).pop(ApplicationInfoPanelResult.none);
                       if (application.hidden) {
                         await appsService.showApplication(application);
                       } else {
                         await appsService.hideApplication(application);
                       }
                     },
                   ),
                   if (category != null)
                     TextButton(
                       child: Row(
                         children: [
                           const Icon(Icons.delete_sweep_outlined),
                           Container(width: 8),
                           Flexible(
                             child: Text(
                               localizations.removeFrom(category!.name),
                               style: Theme.of(context).textTheme.bodyMedium,
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                       ),
                       onPressed: () async {
                         // See hide/show above: close first, then mutate.
                         final AppsService appsService = context.read<AppsService>();
                         Navigator.of(context).pop(ApplicationInfoPanelResult.none);
                         await appsService.removeFromCategory(application, category!);
                       },
                     ),
                   const Divider(),
                   TextButton(
                     child: Row(
                       children: [
                         const Icon(Icons.info_outlined),
                         Container(width: 8),
                         Flexible(
                           child: Text(
                             localizations.appInfo,
                             style: Theme.of(context).textTheme.bodyMedium,
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                       ],
                     ),
                     onPressed: () => context.read<AppsService>().openAppInfo(application),
                   ),
                   TextButton(
                     child: Row(
                       children: [
                         const Icon(Icons.delete_outlined),
                         Container(width: 8),
                         Flexible(
                           child: Text(
                             localizations.uninstall,
                             style: Theme.of(context).textTheme.bodyMedium,
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                       ],
                     ),
                     onPressed: () async {
                       final AppsService appsService = context.read<AppsService>();
                       Navigator.of(context).pop(ApplicationInfoPanelResult.none);
                       await appsService.uninstallApp(application);
                     },
                   )
                 ]
                )
              )
            )
          ]
        )
      );
  }
}

enum ApplicationInfoPanelResult { none, reorderApp }
