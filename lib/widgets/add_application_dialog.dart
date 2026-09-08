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

import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/app.dart';
import '../models/category.dart';

class AddApplicationDialog extends StatelessWidget {
  final Category category;

  const AddApplicationDialog({super.key, required this.category});

  @override
  Widget build(BuildContext context) => Selector<AppsService, List<App>>(
        selector: (_, appsService) => appsService.applications
            .where((application) => !application.hidden && !category.applications.any((app) => app.packageName == application.packageName))
            .toList(),
        builder: (context, applications, _) {
          AppLocalizations localizations = AppLocalizations.of(context)!;

          return SimpleDialog(
          title: Text(localizations.withEllipsisAddApplication),
          contentPadding: EdgeInsets.all(16),
          children: applications.isEmpty
              ? [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      localizations.textNoApplicationsToAdd,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ]
              : applications
                  .map(
                    (application) => AddApplicationListItem(
                      category: category,
                      application: application,
                    ),
                  )
                  .toList(),
        );
        },
      );
}

class AddApplicationListItem extends StatefulWidget {
  final Category category;
  final App application;

  const AddApplicationListItem({
    super.key,
    required this.category,
    required this.application,
  });

  @override
  State<AddApplicationListItem> createState() => _AddApplicationListItemState();
}

class _AddApplicationListItemState extends State<AddApplicationListItem> {
  late Future<Uint8List> _iconLoadFuture;

  @override
  void initState() {
    super.initState();

    _iconLoadFuture = Provider.of<AppsService>(context, listen: false).getAppIcon(widget.application.packageName);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Uint8List>(
        future: _iconLoadFuture,
        builder: (context, snapshot) {
          Widget appIcon;

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            appIcon = Image.memory(snapshot.data!, height: 48);
          }
          else if (snapshot.hasError) {
            appIcon = const Icon(Icons.warning);
          }
          else {
            appIcon = const SizedBox(
              height: 48,
              width: 48,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              )
            );
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              widget.application.name,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            leading: appIcon,
            onTap: () async {
              await context.read<AppsService>().addToCategory(widget.application, widget.category);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          );
        },
      ),
    );
  }
}