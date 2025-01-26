import 'dart:async';
import 'dart:io';

import 'package:eco_walk/api.dart';
import 'package:eco_walk/distance_check.dart';
import 'package:eco_walk/pages/walk_recap_page.dart';
import 'package:eco_walk/pages/walk_start_overlay.dart';
import 'package:eco_walk/widgets/history_widget.dart';
import 'package:eco_walk/widgets/point_of_interest_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

const _distanceBetweenPrompts = 300.0;
const _minimumDurationBetweenPrompts = Duration(seconds: 15);

class AnnotationClickListener extends OnPointAnnotationClickListener {
  final Function(PointAnnotation) onClick;

  AnnotationClickListener({required this.onClick});

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onClick(annotation);
  }
}

class WalkPage extends StatefulWidget {
  final AppState appState;

  const WalkPage({super.key, required this.appState});

  @override
  State<WalkPage> createState() => _WalkPageState();
}

class _WalkPageState extends State<WalkPage> {
  static const _updateInterval = Duration(milliseconds: 400);
  final Map<String, int> _poiIndices = {};

  ByteData? pointBytes;
  Timer? _updateTimer;
  MapboxMap? mapboxMap;

  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;
  PolylineAnnotation? _polylineAnnotation;

  DateTime? _lastInterestPopup;
  Position? _lastInterestPoint;
  Position? _interestPoint;

  var _isBrowsing = false;

  @override
  void initState() {
    widget.appState.currentWalk = apiCreateWalkNoPublish(widget.appState);
    super.initState();
  }

  Future<void> _pickNextPointOfInterest(Position position) async {
    _lastInterestPoint = position;
    _lastInterestPopup = DateTime.now();

    final poi = await apiFindPointOfInterest(position, _distanceBetweenPrompts * 0.95);
    if (poi != null) {
      widget.appState.currentWalk!.pois.add(poi);

      final annotation = await pointAnnotationManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: poi.position),
        image: pointBytes?.buffer.asUint8List(),
        iconSize: 0.2,
        textField: poi.name,
        textOffset: [0.0, -3.0],
      ));
      _poiIndices[annotation.id] = widget.appState.currentWalk!.pois.length - 1;

      await _showPointOfInterest(poi);
    }
  }

  Future<void> _showPointOfInterest(PointOfInterest poi) async {
    _interestPoint = poi.position;

    await showModalBottomSheet(
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: 400,
      ),
      context: context,
      builder: (context) => PointOfInterestSheet(poi: poi),
    );
    if (!mounted) return;
    _interestPoint = null;
  }

  void _update() async {
    Layer? layer;
    if (Platform.isAndroid) {
      layer = await mapboxMap?.style.getLayer('mapbox-location-indicator-layer');
    } else {
      layer = await mapboxMap?.style.getLayer('puck');
    }

    final location = (layer as LocationIndicatorLayer).location;
    if (location == null) return;

    final bearing = layer.bearing!;
    final position = Position(location[1]!, location[0]!);

    if (widget.appState.currentWalk!.points.isEmpty) {
      widget.appState.currentWalk!.points.add(position);

      _polylineAnnotation = await polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: [position]),
          lineWidth: 6.0,
          lineColor: Theme.of(context).colorScheme.primary.value,
        ),
      );
    } else if (!isWithinRadiusMeters(widget.appState.currentWalk!.points.last, position, 5.0)) {
      widget.appState.currentWalk!.points.add(position);

      if (!mounted) return;

      polylineAnnotationManager!.delete(_polylineAnnotation!);
      _polylineAnnotation = await polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: widget.appState.currentWalk!.points),
          lineWidth: 6.0,
          lineColor: Theme.of(context).colorScheme.primary.value,
        ),
      );
    }

    if (_lastInterestPoint == null || _lastInterestPopup == null) {
      _lastInterestPoint = position;
      _lastInterestPopup = DateTime.now();
    } else {
      if (DateTime.now().difference(_lastInterestPopup!) >= _minimumDurationBetweenPrompts && !isWithinRadiusMeters(_lastInterestPoint!, position, _distanceBetweenPrompts)) {
        _lastInterestPoint = position;
        _lastInterestPopup = DateTime.now();

        await _pickNextPointOfInterest(position);
      }
    }

    CameraOptions cameraOptions;
    if (_interestPoint != null) {
      cameraOptions = await mapboxMap!.cameraForCoordinatesPadding(
        [
          Point(coordinates: _interestPoint!),
          if (!_isBrowsing) Point(coordinates: position),
        ],
        CameraOptions(
          center: Point(
            coordinates: position,
          ),
          bearing: _isBrowsing ? null : bearing,
          pitch: 35.0,
          zoom: 18.0,
        ),
        MbxEdgeInsets(top: 100.0, left: 100.0, bottom: 550.0, right: 100.0),
        18.0,
        null,
      );
    } else {
      if (_isBrowsing) return;

      cameraOptions = CameraOptions(
        center: Point(
          coordinates: position,
        ),
        bearing: bearing,
        pitch: 35.0,
        zoom: 18.0,
      );
    }

    mapboxMap?.flyTo(
      cameraOptions,
      MapAnimationOptions(
        duration: _updateInterval.inMilliseconds,
      ),
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Scaffold(
            body: MapWidget(
              onMapCreated: (mapboxMap) async {
                this.mapboxMap = mapboxMap;

                pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                pointAnnotationManager?.addOnPointAnnotationClickListener(AnnotationClickListener(
                  onClick: (annotation) async {
                    final index = _poiIndices[annotation.id];
                    if (index == null) return;

                    final poi = widget.appState.currentWalk!.pois[index];
                    await _showPointOfInterest(poi);
                  },
                ));

                polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();

                final puckBytes = await rootBundle.load('assets/puck.png');
                pointBytes = await rootBundle.load('assets/point.png');

                await mapboxMap.location.updateSettings(
                  LocationComponentSettings(
                    enabled: true,
                    puckBearingEnabled: true,
                    locationPuck: LocationPuck(
                      locationPuck2D: LocationPuck2D(
                        bearingImage: puckBytes.buffer.asUint8List(),
                        scaleExpression: '0.2',
                      ),
                      // locationPuck3D: LocationPuck3D(
                      //   modelUri: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Embedded/Duck.gltf",
                      //   modelScale: [100.0, 100.0, 100.0],
                      // ),
                    ),
                  ),
                );

                mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
                mapboxMap.compass.updateSettings(CompassSettings(enabled: false));

                _updateTimer = Timer.periodic(_updateInterval, (_) {
                  _update();
                });

                mapboxMap.setOnMapMoveListener((ctx) {
                  setState(() => _isBrowsing = true);
                });
              },
            ),
            floatingActionButton: _isBrowsing
                ? FloatingActionButton(
                    onPressed: () {
                      setState(() => _isBrowsing = false);
                    },
                    child: Transform.rotate(
                      angle: -45.0 * degToRad,
                      child: Icon(BoxIcons.bxs_send),
                    ),
                  )
                : null,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.inversePrimary,
                    Theme.of(context).colorScheme.inversePrimary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 50.0,
                  child: Row(
                    children: [
                      SizedBox(width: 24.0),
                      FilledButton.tonalIcon(
                        label: Text('End Walk'),
                        icon: Icon(BoxIcons.bx_x),
                        onPressed: () async {
                          final shouldEnd = await showDialog(
                            context: context,
                            builder: (context) => _EndWalkDialog(
                              appState: widget.appState,
                            ),
                          );
                          if (!context.mounted) return;
                          if (shouldEnd == true) {
                            Navigator.of(context).pop(true);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => WalkRecapPage(
                                      appState: widget.appState,
                                      walk: widget.appState.currentWalk!,
                                    )));
                            if (refreshHistoryList != null) refreshHistoryList!();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Positioned(
          //   bottom: 100,
          //   left: 16,
          //   child: FilledButton(
          //     child: Text('Fact Test'),
          //     onPressed: () async {
          //       Layer? layer;
          //       if (Platform.isAndroid) {
          //         layer = await mapboxMap?.style.getLayer('mapbox-location-indicator-layer');
          //       } else {
          //         layer = await mapboxMap?.style.getLayer('puck');
          //       }

          //       final location = (layer as LocationIndicatorLayer).location;
          //       if (location == null) return;

          //       final bearing = layer.bearing!;
          //       final position = Position(location[1]!, location[0]!);

          //       await _pickNextPointOfInterest(position);
          //     },
          //   ),
          // ),
          WalkStartOverlay(),
        ],
      ),
    );
  }
}

class _EndWalkDialog extends StatefulWidget {
  final AppState appState;

  const _EndWalkDialog({required this.appState});

  @override
  State<_EndWalkDialog> createState() => _EndWalkDialogState();
}

class _EndWalkDialogState extends State<_EndWalkDialog> {
  var _loading = false;

  void _endWalk() async {
    try {
      setState(() => _loading = true);
      final name = await apiGetWalkName(widget.appState.currentWalk!);
      widget.appState.currentWalk!.name = name ?? 'Unnamed Walk';
      await apiPublishWalk(widget.appState, widget.appState.currentWalk!);
    } finally {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('End Walk'),
      content: Text('Are you sure you want to end your walk?'),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: Text('Back'),
        ),
        FilledButton.tonal(
          onPressed: _loading
              ? null
              : () {
                  _endWalk();
                },
          child: Text('End Walk'),
        ),
      ],
    );
  }
}
