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

import 'dart:convert';

import 'package:flauncher/models/weather.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class WeatherPanelPage extends StatelessWidget {
  static const String routeName = "weather_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService settingsService = Provider.of(context);
    WeatherService weatherService = Provider.of(context);
    WeatherLocation? location = weatherService.location;

    return Column(
        children: [
          Text(localizations.weather, style: Theme.of(context).textTheme.titleLarge),
          Divider(),
          RoundedSwitchListTile(
            autofocus: true,
            value: settingsService.weatherEnabled,
            onChanged: (value) => settingsService.setWeatherEnabled(value),
            title: Text(localizations.weatherShowWeather, style: Theme.of(context).textTheme.bodyMedium),
            secondary: Icon(Icons.cloud_outlined),
          ),
          RoundedSwitchListTile(
            value: settingsService.weatherAutoLocation,
            onChanged: (value) => settingsService.setWeatherAutoLocation(value),
            title: Text(localizations.weatherAutoLocate, style: Theme.of(context).textTheme.bodyMedium),
            secondary: Icon(Icons.my_location),
          ),
          Divider(),
          if (settingsService.weatherAutoLocation)
            Row(
              children: [
                const Icon(Icons.place),
                Container(width: 8),
                Expanded(child: Text(
                  location?.label ?? localizations.weatherLocating,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            )
          else
            TextButton(
              child: Row(
                children: [
                  const Icon(Icons.place),
                  Container(width: 8),
                  Flexible(child: Text(
                    location?.label ?? localizations.weatherNoLocation,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
              onPressed: () async => await _chooseCityDialog(context),
            ),
        ],
      );
  }

  Future<void> _chooseCityDialog(BuildContext context) async {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    WeatherService weatherService = context.read<WeatherService>();
    SettingsService settingsService = context.read<SettingsService>();

    final location = await showDialog<WeatherLocation>(
        context: context,
        builder: (_) => _CitySearchDialog(weatherService: weatherService, localizations: localizations)
    );

    if (location != null) {
      await settingsService.setWeatherLocationJson(jsonEncode(location.toJson()));
    }
  }
}

class _CitySearchDialog extends StatefulWidget {
  final WeatherService weatherService;
  final AppLocalizations localizations;

  const _CitySearchDialog({required this.weatherService, required this.localizations});

  @override
  State<_CitySearchDialog> createState() => _CitySearchDialogState();
}

class _CitySearchDialogState extends State<_CitySearchDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _searching = false;
  List<WeatherLocation>? _results;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      insetPadding: EdgeInsets.only(bottom: 120),
      contentPadding: EdgeInsets.all(24),
      title: Text(widget.localizations.weatherChooseCity),
      children: [
        TextField(
          autofocus: true,
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.localizations.weatherChooseCity,
            hintText: widget.localizations.weatherSearchHint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
        SizedBox(
          height: 250,
          width: 300,
          child: _buildResults(),
        )
      ],
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    else if (_results == null) {
      return Center(child: Text(widget.localizations.weatherSearchHint));
    }
    else if (_results!.isEmpty) {
      return Center(child: Text(widget.localizations.weatherNoResults));
    }
    else {
      return ListView.builder(
        itemCount: _results!.length,
        itemBuilder: (context, index) {
          final location = _results![index];
          return SimpleDialogOption(
            child: Text(location.label, overflow: TextOverflow.ellipsis),
            onPressed: () => Navigator.of(context).pop(location),
          );
        },
      );
    }
  }

  Future<void> _search() async {
    final query = _controller.text.trim();

    if (query.isEmpty || _searching) {
      return;
    }

    setState(() {
      _searching = true;
      _results = null;
    });

    try {
      final results = await widget.weatherService.searchCities(query);
      if (mounted) {
        setState(() => _results = results);
      }
    }
    catch (e) {
      if (mounted) {
        setState(() => _results = []);
      }
    }
    finally {
      _searching = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}