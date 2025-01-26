import 'package:eco_walk/api.dart';
import 'package:flutter/material.dart';

class UserIconWidget extends StatelessWidget {
  final ESUser? esUser;
  final String? name;
  final double radius;

  const UserIconWidget({super.key, this.esUser, this.name, this.radius = 20.0});

  @override
  Widget build(BuildContext context) {
    return esUser != null && esUser!.hasIcon
        ? CircleAvatar(
            radius: radius,
            backgroundImage: apiGetUserIcon(esUser!.key),
          )
        : CircleAvatar(
            radius: radius,
            child: Text(
              esUser?.name.characters.first.toUpperCase() ?? name!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: radius - 4.0),
            ),
          );
  }
}
