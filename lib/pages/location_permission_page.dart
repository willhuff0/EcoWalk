import 'dart:io';

import 'package:eco_walk/main.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:icons_plus/icons_plus.dart';

class LocationPermissionPage extends StatefulWidget {
  const LocationPermissionPage({super.key});

  @override
  State<LocationPermissionPage> createState() => _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage> {
  var _loading = false;

  void _requestPermission() async {
    if (_loading) return;
    try {
      setState(() => _loading = true);
      await Geolocator.requestPermission();
      checkLocationPermission();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Align(
          alignment: const Alignment(0.0, 0.1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(flex: 4, child: Container()),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text(
                      'Location',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 64.0,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(height: 14.0),
                  Text(
                    '$appName requires your location to track your walking distance.',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 24.0,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (Platform.isIOS || Platform.isMacOS) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      "Select 'While using the app' when prompted to ensure $appName works properly.",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                    ),
                  ] else if (Platform.isAndroid) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      "Select 'Precise' and 'While using the app' when prompted to ensure $appName works properly.",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                    ),
                  ],
                ],
              ),
              Expanded(flex: 3, child: Container()),
              FilledButton.icon(
                onPressed: _loading ? null : _requestPermission,
                icon: const Icon(BoxIcons.bx_street_view),
                label: const Text('While using the app'),
              ),
              Expanded(flex: 3, child: Container()),
            ],
          ),
        ),
      ),
    );
  }
}
