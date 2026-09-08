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

import 'package:flauncher/providers/memory_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Status-bar widget showing the currently available memory. Pressing it runs
/// a one-tap clean and reports the real amount of memory that was freed.
class MemoryWidget extends StatelessWidget
{
  const MemoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MemoryService>(
      builder: (context, memoryService, _) {
        AppLocalizations localizations = AppLocalizations.of(context)!;

        Widget icon;
        if (memoryService.cleaning) {
          icon = const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)
          );
        }
        else {
          // Highlight the chip when memory is running low.
          bool lowMemory = memoryService.initialized && memoryService.availPercent < 15;
          Color? color = lowMemory ? Theme.of(context).colorScheme.error : null;
          icon = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.memory_outlined,
                color: color,
                shadows: const [
                  Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)
                ]
              ),
              if (memoryService.initialized) ...[
                const SizedBox(width: 4),
                Text("${memoryService.availPercent}%",
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: color,
                    shadows: const [
                      Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)
                    ]
                  )
                )
              ]
            ]
          );
        }

        return IconButton(
          padding: const EdgeInsets.all(2),
          constraints: const BoxConstraints(),
          splashRadius: 20,
          tooltip: localizations.oneTapClean,
          icon: icon,
          onPressed: memoryService.cleaning ? null : () async {
            int freed = await memoryService.clean();
            if (!context.mounted) {
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(seconds: 4),
              content: Text(freed == 0
                ? localizations.memoryAlreadyClean
                : localizations.memoryFreed(formatBytes(freed)))
            ));
          },
          // sometime after Flutter 3.7.5, no later than 3.16.8, the focus highlight went away
          focusColor: Theme.of(context).primaryColorLight,
        );
      }
    );
  }
}

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  return "${(bytes / (1024 * 1024)).round()} MB";
}