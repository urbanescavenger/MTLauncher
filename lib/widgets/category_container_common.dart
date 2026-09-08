import 'package:flauncher/widgets/add_application_dialog.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/category.dart';
import 'ensure_visible.dart';

Widget categoryContainerEmptyState(BuildContext context) {
  AppLocalizations localizations = AppLocalizations.of(context)!;

  return SizedBox(
    height: 110,
    child: EnsureVisible(
      // This specific alignment value is not only
      // to center the focused card in the row while
      // scrolling, but to prevent the topmost category
      // title to be hidden by the content above it when
      // scrolling from the app bar. How it relates to this,
      // I don't know
      alignment: 0.5,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: InkWell(
                autofocus: true,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => SettingsPanel(initialRoute: LauncherSectionsPanelPage.routeName),
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      localizations.textEmptyCategory,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AddAppCard extends StatefulWidget {
  final Category category;

  const AddAppCard({super.key, required this.category});

  @override
  State<AddAppCard> createState() => _AddAppCardState();
}

class _AddAppCardState extends State<AddAppCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: AnimatedScale(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      scale: _focused ? 1.1 : 1.0,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: _focused ? 16 : 0,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          focusColor: Colors.transparent,
          onFocusChange: (focused) {
            setState(() => _focused = focused);
            if (focused) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                curve: Curves.easeInOut,
                duration: const Duration(milliseconds: 100)
              );
            }
          },
          onTap: () => showDialog(
            context: context,
            builder: (_) => AddApplicationDialog(category: widget.category),
          ),
          child: const Center(
            child: Icon(Icons.add, size: 48),
          ),
        ),
      ),
    ),
  );
}