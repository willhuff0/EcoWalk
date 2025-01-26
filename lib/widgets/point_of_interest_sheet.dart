import 'package:eco_walk/api.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class PointOfInterestSheet extends StatelessWidget {
  final PointOfInterest poi;

  const PointOfInterestSheet({super.key, required this.poi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(36.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(poi.name, style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    icon: Icon(BoxIcons.bx_chevron_down),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              SizedBox(height: 4.0),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(poi.funFact),
                    ),
                  ),
                  Positioned(
                    top: -8.0,
                    left: -8.0,
                    child: Icon(
                      BoxIcons.bxs_leaf,
                      size: 32.0,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                ],
              ),
              Card(
                surfaceTintColor: Theme.of(context).colorScheme.brightness == Brightness.light ? Colors.white : Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(poi.description),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
