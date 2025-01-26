import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class LeafCountWidget extends StatelessWidget {
  final int count;

  const LeafCountWidget({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count > 3) {
      return Card(
        elevation: 2.0,
        surfaceTintColor: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Row(
            children: [
              Icon(
                BoxIcons.bxs_leaf,
                size: 28.0,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              SizedBox(width: 4.0),
              Text(count.toString(), style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count,
          (index) => Icon(BoxIcons.bxs_leaf, size: 28.0, color: Theme.of(context).colorScheme.inversePrimary),
        ),
      );
    }
  }
}
