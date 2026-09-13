/*
 * FLauncher
 * Copyright (C) 2024  Oscar Rojas
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

import 'package:flauncher/models/category.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/app.dart';

/// Third launcher page: a grid showing every installed (non-hidden)
/// application, sorted alphabetically. Cards are not tied to any category, so
/// they cannot be reordered or removed here.
class AllAppsGrid extends StatelessWidget {
  final List<App> applications;

  const AllAppsGrid({
    super.key,
    required this.applications,
  });

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    Widget gridContent;
    if (applications.isEmpty) {
      gridContent = const SizedBox.shrink();
    }
    else {
      // 瓦片高度 = 卡片(按宽度 16:9)+ 下方应用名标签。
      gridContent = LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = (constraints.maxWidth - 32 - (Category.ColumnsCount - 1) * 16) / Category.ColumnsCount;
          final cardHeight = tileWidth * 9 / 16;

          return GridView.custom(
            primary: false,
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Category.ColumnsCount,
              mainAxisExtent: cardHeight + appCardLabelHeight,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            padding: const EdgeInsets.all(16),
            childrenDelegate: SliverChildBuilderDelegate(
              childCount: applications.length,
              findChildIndexCallback: _findChildIndex,
              (context, index) => Column(
                children: [
                  Expanded(
                    child: AppCard(
                      key: Key(applications[index].packageName),
                      application: applications[index],
                      autofocus: index == 0,
                    ),
                  ),
                  appCardLabel(context, applications[index].name)
                ],
              ),
            ),
          );
        }
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(localizations.allApplications,
            style: Theme.of(context)
                .textTheme
                .titleLarge!
                .copyWith(shadows: [const Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 8)])
          ),
        ),
        gridContent,
      ],
    );
  }

  int _findChildIndex(Key key) =>
      applications.indexWhere((app) => app.packageName == (key as ValueKey<String>).value);
}