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

import 'dart:async';

import 'package:flauncher/app_image_type.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/dock_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const _validationKeys = [LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA];

class DockBar extends StatelessWidget {
  const DockBar({super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<DockService>(
      builder: (context, dockService, _) {
        final appsService = context.read<AppsService>();
        final applications = dockService.packageNames
            .map((packageName) => appsService.getApplication(packageName))
            .whereType<App>()
            .toList();

        if (applications.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                localizations.dockEmptyHint,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(shadows: [const Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 8)]),
              ),
            ),
          );
        }

        return SizedBox(
          height: DockCard.height + 16,
          child: ListView.custom(
            padding: const EdgeInsets.all(8),
            scrollDirection: Axis.horizontal,
            childrenDelegate: SliverChildBuilderDelegate(
              childCount: applications.length,
              findChildIndexCallback: _findChildIndex(applications),
              (context, index) => Padding(
                  key: Key(applications[index].packageName),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DockCard(
                    application: applications[index],
                    autofocus: index == 0,
                    onMove: (direction) => _onMove(context, direction, index),
                    onMoveEnd: () => _onMoveEnd(context),
                  )
              ),
            ),
          ),
        );
      },
    );
  }

  int Function(Key) _findChildIndex(List<App> applications) =>
      (key) => applications.indexWhere((app) => app.packageName == (key as ValueKey<String>).value);

  void _onMove(BuildContext context, AxisDirection direction, int index) {
    final dockService = context.read<DockService>();
    int newIndex;

    if (direction == AxisDirection.right && index < dockService.packageNames.length - 1) {
      newIndex = index + 1;
    } else if (direction == AxisDirection.left && index > 0) {
      newIndex = index - 1;
    } else {
      return;
    }

    dockService.reorderApp(index, newIndex);
  }

  void _onMoveEnd(BuildContext context) {
    context.read<DockService>().saveOrder();
  }
}

class DockCard extends StatefulWidget {
  static const double height = 100;

  final App application;
  final bool autofocus;
  final void Function(AxisDirection) onMove;
  final VoidCallback onMoveEnd;

  const DockCard({
    super.key,
    required this.application,
    required this.autofocus,
    required this.onMove,
    required this.onMoveEnd,
  });

  @override
  State<DockCard> createState() => _DockCardState();
}

class _DockCardState extends State<DockCard> with SingleTickerProviderStateMixin {
  bool _moving = false;

  late Future<Tuple2<AppImageType, ImageProvider>> _appImageLoadFuture;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 255,
    duration: const Duration(
      milliseconds: 800,
    ),
  );

  @override
  void initState() {
    super.initState();

    FocusManager.instance.addHighlightModeListener(_focusHighlightModeChanged);
    _appImageLoadFuture = _loadAppBannerOrIcon(Provider.of<AppsService>(context, listen: false));
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_focusHighlightModeChanged);
    _animation.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusKeyboardListener(
      onPressed: (key) => _onPressed(context, key),
      onLongPress: (key) => _onLongPress(context, key),
      builder: (context) {
        final bool shouldHighlight = _shouldHighlight(context);

        return SizedBox(
          height: DockCard.height,
          width: 178,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transformAlignment: Alignment.center,
            transform: _scaleTransform(context),
            child: Material(
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              elevation: shouldHighlight ? 16 : 0,
              shadowColor: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InkWell(
                    autofocus: widget.autofocus,
                    focusColor: Colors.transparent,
                    child: _appImage(),
                    onTap: () => _onPressed(context, LogicalKeyboardKey.enter),
                    onLongPress: () => _onLongPress(context, LogicalKeyboardKey.enter),
                    onFocusChange: (focused) {
                      Scrollable.ensureVisible(
                        context,
                        alignment: 0.5,
                        curve: Curves.easeInOut,
                        duration: Duration(milliseconds: 100)
                      );
                    },
                  ),
                  if (_moving) ..._arrows(),
                  IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      opacity: shouldHighlight ? 0 : 0.10,
                      child: Container(color: Colors.black),
                    ),
                  ),
                  Selector<SettingsService, bool>(
                    selector: (_, settingsService) => settingsService.appHighlightAnimationEnabled && shouldHighlight,
                    builder: (context, highlight, _) {
                      if (highlight) {
                        _animation.repeat(reverse: true);
                        return AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) => IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withAlpha(_animation.value.round()),
                                  width: 3
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      _animation.stop();
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
  );

  Future<Tuple2<AppImageType, ImageProvider>> _loadAppBannerOrIcon(AppsService service) async {
    Uint8List bytes = Uint8List(0);

    bytes = await service.getAppBanner(widget.application.packageName);
    AppImageType type = AppImageType.Banner;

    if (bytes.isEmpty) {
      type = AppImageType.Icon;
      bytes = await service.getAppIcon(widget.application.packageName);
    }

    return Tuple2(type, MemoryImage(bytes));
  }

  Widget _appImage()
  {
    App app = widget.application;

    return FutureBuilder(
      future: _appImageLoadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          Tuple2<AppImageType, ImageProvider> tuple = snapshot.data!;

          if (tuple.item1 == AppImageType.Banner) {
            return Ink.image(image: tuple.item2, fit: BoxFit.cover);
          }
          else {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Ink.image(
                      image: tuple.item2,
                      height: double.maxFinite,
                    ),
                  ),
                  Flexible(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        app.name,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }
        else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                app.name,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              )
            ),
          );
        }
        else {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 0, width: 16),
                Text("Loading")
              ],
            ),
          );
        }
      }
    );
  }

  void _focusHighlightModeChanged(FocusHighlightMode mode)
  {
    setState(() { });
  }

  bool _shouldHighlight(BuildContext context)
  {
    return FocusManager.instance.highlightMode == FocusHighlightMode.traditional && Focus.of(context).hasFocus;
  }

  Matrix4 _scaleTransform(BuildContext context) {
    double scale = 1.0;
    if (!_moving && _shouldHighlight(context)) {
      scale = 1.1;
    }
    return Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  List<Widget> _arrows() => [
      _arrow(Alignment.centerLeft, Icons.keyboard_arrow_left, () {
        widget.onMove(AxisDirection.left);
      }),
      _arrow(Alignment.centerRight, Icons.keyboard_arrow_right, () {
        widget.onMove(AxisDirection.right);
      })
  ];

  Widget _arrow(Alignment alignment, IconData icon, VoidCallback onTap) =>
      Align(
        alignment: alignment,
        child: Ink(
          decoration: ShapeDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.8),
            shape: CircleBorder()
          ),
          child: SizedBox(
            height: 36,
            width: 36,
            child: IconButton(
              icon: Icon(icon, size: 24),
              onPressed: onTap,
              padding: EdgeInsets.all(0)
            )
          )
        )
      );

  KeyEventResult _onPressed(BuildContext context, LogicalKeyboardKey? key) {
    if (_moving) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        widget.onMove(AxisDirection.left);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        widget.onMove(AxisDirection.right);
      } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
        // Consume the key so the dock page is not switched while reordering
      } else if (_validationKeys.contains(key) || key == LogicalKeyboardKey.escape) {
        setState(() => _moving = false);
        widget.onMoveEnd();
      } else {
        return KeyEventResult.ignored;
      }

      return KeyEventResult.handled;
    } else if (_validationKeys.contains(key)) {
      context.read<AppsService>().launchApp(widget.application);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onLongPress(BuildContext context, LogicalKeyboardKey? key) {
    if (!_moving && (key == null || longPressableKeys.contains(key))) {
      _showPanel(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showPanel(BuildContext context) async {
    final result = await showDialog<ApplicationInfoPanelResult>(
      context: context,
      builder: (context) => ApplicationInfoPanel(
        application: widget.application,
        dockContext: true,
      ),
    );
    if (result == ApplicationInfoPanelResult.reorderApp) {
      setState(() => _moving = true);
    }
  }
}