/*
 * FLauncher
 * Copyright (C) 2024 Oscar Rojas
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

import 'dart:ui';

import 'package:flauncher/models/weather.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Frosted-glass weather card for the top-left corner of the home screen.
/// Non-interactive on purpose: it must never take part in D-pad traversal.
class WeatherWidget extends StatelessWidget {
  const WeatherWidget();

  @override
  Widget build(BuildContext context) => Consumer<WeatherService>(
    builder: (context, weatherService, __) {
      final location = weatherService.location;
      final weather = weatherService.currentWeather;

      if (!weatherService.enabled || location == null || weather == null) {
        return const SizedBox.shrink();
      }

      return ExcludeFocus(
        child: _WeatherCard(location: location, weather: weather)
      );
    },
  );
}

class _WeatherCard extends StatelessWidget {
  final WeatherLocation location;
  final WeatherData weather;

  const _WeatherCard({required this.location, required this.weather});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white.withOpacity(0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_kindIcon, size: 44, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    "${weather.temperature.round()}°C",
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)],
                    ),
                  ),
                ],
              ),
              Text(
                _conditionText(localizations),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    location.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _kindIcon {
    switch (weather.kind) {
      case WeatherKind.clear:
        return weather.isDay ? Icons.wb_sunny : Icons.nightlight_round;
      case WeatherKind.mostlyClear:
      case WeatherKind.partlyCloudy:
        return Icons.filter_drama;
      case WeatherKind.overcast:
      case WeatherKind.fog:
        return Icons.cloud;
      case WeatherKind.drizzle:
      case WeatherKind.lightRain:
      case WeatherKind.rain:
      case WeatherKind.heavyRain:
      case WeatherKind.freezingRain:
        return Icons.water_drop;
      case WeatherKind.showers:
        return Icons.umbrella;
      case WeatherKind.lightSnow:
      case WeatherKind.snow:
      case WeatherKind.heavySnow:
      case WeatherKind.snowShowers:
        return Icons.ac_unit;
      case WeatherKind.thunderstorm:
      case WeatherKind.thunderstormHail:
        return Icons.flash_on;
    }
  }

  String _conditionText(AppLocalizations localizations) {
    switch (weather.kind) {
      case WeatherKind.clear:
        return localizations.weatherClear;
      case WeatherKind.mostlyClear:
        return localizations.weatherMostlyClear;
      case WeatherKind.partlyCloudy:
        return localizations.weatherPartlyCloudy;
      case WeatherKind.overcast:
        return localizations.weatherOvercast;
      case WeatherKind.fog:
        return localizations.weatherFog;
      case WeatherKind.drizzle:
        return localizations.weatherDrizzle;
      case WeatherKind.lightRain:
        return localizations.weatherLightRain;
      case WeatherKind.rain:
        return localizations.weatherRain;
      case WeatherKind.heavyRain:
        return localizations.weatherHeavyRain;
      case WeatherKind.freezingRain:
        return localizations.weatherFreezingRain;
      case WeatherKind.lightSnow:
        return localizations.weatherLightSnow;
      case WeatherKind.snow:
        return localizations.weatherSnow;
      case WeatherKind.heavySnow:
        return localizations.weatherHeavySnow;
      case WeatherKind.showers:
        return localizations.weatherShowers;
      case WeatherKind.snowShowers:
        return localizations.weatherSnowShowers;
      case WeatherKind.thunderstorm:
        return localizations.weatherThunderstorm;
      case WeatherKind.thunderstormHail:
        return localizations.weatherThunderstormHail;
    }
  }
}