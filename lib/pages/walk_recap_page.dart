import 'dart:async';

import 'package:eco_walk/api.dart';
import 'package:eco_walk/widgets/history_widget.dart';
import 'package:eco_walk/widgets/point_of_interest_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class AnnotationClickListener extends OnPointAnnotationClickListener {
  final Function(PointAnnotation) onClick;

  AnnotationClickListener({required this.onClick});

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onClick(annotation);
  }
}

class WalkRecapPage extends StatefulWidget {
  final AppState appState;
  final ESWalk walk;

  const WalkRecapPage({super.key, required this.appState, required this.walk});

  @override
  State<WalkRecapPage> createState() => _WalkRecapPageState();
}

class _WalkRecapPageState extends State<WalkRecapPage> {
  final Map<String, int> _poiIndices = {};

  ByteData? pointBytes;
  Timer? _updateTimer;
  MapboxMap? mapboxMap;

  var _isBrowsing = false;

  void _returnToFullView() async {
    final cameraOptions = await mapboxMap!.cameraForCoordinatesPadding(
      [
        ...widget.walk.pois.map((poi) => Point(coordinates: poi.position)),
        ...widget.walk.points.map((point) => Point(coordinates: point)),
      ],
      CameraOptions(
        pitch: 35.0,
        bearing: 0.0,
      ),
      MbxEdgeInsets(top: 50.0, left: 50.0, bottom: 50.0, right: 50.0),
      18.0,
      null,
    );

    mapboxMap?.flyTo(
      cameraOptions,
      MapAnimationOptions(
        duration: 600,
      ),
    );
  }

  Future<void> _showPointOfInterest(PointOfInterest poi, int index) async {
    final cameraOptions = await mapboxMap!.cameraForCoordinatesPadding(
      [Point(coordinates: poi.position)],
      CameraOptions(
        pitch: 35.0,
      ),
      MbxEdgeInsets(top: 100.0, left: 100.0, bottom: 550.0, right: 100.0),
      18.0,
      null,
    );

    mapboxMap?.flyTo(
      cameraOptions,
      MapAnimationOptions(
        duration: 600,
      ),
    );

    if (!mounted) return;
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
    if (!_isBrowsing) {
      _returnToFullView();
    }
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

                pointBytes = await rootBundle.load('assets/point.png');

                final pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager(id: 'places');
                pointAnnotationManager.addOnPointAnnotationClickListener(AnnotationClickListener(
                  onClick: (annotation) async {
                    final index = _poiIndices[annotation.id];
                    if (index == null) return;

                    final poi = widget.walk.pois[index];
                    await _showPointOfInterest(poi, index);
                  },
                ));
                for (var i = 0; i < widget.walk.pois.length; i++) {
                  final poi = widget.walk.pois[i];
                  final annotation = await pointAnnotationManager.create(PointAnnotationOptions(
                    geometry: Point(coordinates: poi.position),
                    image: pointBytes?.buffer.asUint8List(),
                    iconSize: 0.2,
                    textField: poi.name,
                    textOffset: [0.0, -3.0],
                  ));
                  _poiIndices[annotation.id] = i;
                }
                // final puckBytes = await rootBundle.load('assets/puck.png');
                await pointAnnotationManager.create(PointAnnotationOptions(
                  geometry: Point(coordinates: widget.walk.points.first),
                  image: pointBytes?.buffer.asUint8List(),
                  iconSize: 0.125,
                  textField: 'Start',
                  textOffset: [0.0, -2.0],
                ));
                await pointAnnotationManager.create(PointAnnotationOptions(
                  geometry: Point(coordinates: widget.walk.points.last),
                  image: pointBytes?.buffer.asUint8List(),
                  iconSize: 0.125,
                  textField: 'End',
                  textOffset: [0.0, -2.0],
                ));

                final polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager(id: 'line', below: 'places');
                if (!context.mounted) return;
                await polylineAnnotationManager.create(PolylineAnnotationOptions(
                  geometry: LineString(coordinates: widget.walk.points),
                  lineWidth: 6.0,
                  lineColor: Theme.of(context).colorScheme.primary.value,
                ));

                mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
                mapboxMap.compass.updateSettings(CompassSettings(enabled: false));

                mapboxMap.setOnMapMoveListener((ctx) {
                  setState(() => _isBrowsing = true);
                });

                _returnToFullView();
              },
            ),
            floatingActionButton: _isBrowsing
                ? FloatingActionButton(
                    onPressed: () {
                      setState(() => _isBrowsing = false);
                      _returnToFullView();
                    },
                    child: Icon(BoxIcons.bxs_map_pin),
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
                        label: Text('Back'),
                        icon: Icon(BoxIcons.bx_chevron_left),
                        onPressed: () async {
                          Navigator.pop(context);
                        },
                      ),
                      Spacer(),
                      FilledButton.tonalIcon(
                        label: Text('Delete Walk'),
                        icon: Icon(BoxIcons.bx_trash),
                        onPressed: () async {
                          final shouldEnd = await showDialog(
                            context: context,
                            builder: (context) => _DeleteWalkDialog(
                              appState: widget.appState,
                              walk: widget.walk,
                            ),
                          );
                          if (!context.mounted) return;
                          if (shouldEnd == true) {
                            Navigator.of(context).pop();
                            if (refreshHistoryList != null) refreshHistoryList!();
                          }
                        },
                      ),
                      SizedBox(width: 24.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteWalkDialog extends StatefulWidget {
  final AppState appState;
  final ESWalk walk;

  const _DeleteWalkDialog({required this.appState, required this.walk});

  @override
  State<_DeleteWalkDialog> createState() => _DeleteWalkDialogState();
}

class _DeleteWalkDialogState extends State<_DeleteWalkDialog> {
  var _loading = false;

  void _deleteWalk() async {
    try {
      setState(() => _loading = true);
      await apiDeleteWalk(widget.appState, widget.walk);
    } finally {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete Walk'),
      content: Text('Are you sure you want to delete this walk?'),
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
                  _deleteWalk();
                },
          child: Text('Delete Walk'),
        ),
      ],
    );
  }
}
