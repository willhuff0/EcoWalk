import 'package:eco_walk/api.dart';
import 'package:eco_walk/widgets/user_icon.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class ESDrawer extends StatelessWidget {
  final AppState appState;

  const ESDrawer({super.key, required this.appState});

  void _logOutButton(BuildContext context) {
    showDialog(context: context, builder: (context) => const _LogOutDialog());
  }

  void _settingsButton(BuildContext context) {
    //Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage(appState: appState)));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: true,
        bottom: true,
        left: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Card(
                clipBehavior: Clip.hardEdge,
                shadowColor: Colors.transparent,
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  leading: UserIconWidget(esUser: appState.esUser),
                  title: Text(appState.esUser.name),
                  onTap: () => _settingsButton(context),
                ),
              ),
              const Divider(),
              // Card(
              //   surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
              //   clipBehavior: Clip.hardEdge,
              //   shadowColor: Colors.transparent,
              //   child: ListTile(
              //     leading: const Icon(BoxIcons.bx_cog),
              //     title: const Text('Settings'),
              //     onTap: () => _settingsButton(context),
              //   ),
              // ),
              Expanded(child: Container()),
              Text('Made with ❤️ by Will Huffman in Florida'),
              const Divider(),
              Card(
                surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
                clipBehavior: Clip.hardEdge,
                shadowColor: Colors.transparent,
                child: ListTile(
                  leading: const Icon(BoxIcons.bx_log_out),
                  title: const Text('Log Out'),
                  onTap: () => _logOutButton(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogOutDialog extends StatelessWidget {
  const _LogOutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Out?'),
      content: const Text('Your information will be removed from this device, and you may have to sign in again.'),
      actions: [
        TextButton(
          onPressed: () {
            apiLogOut();
            Navigator.pop(context, true);
          },
          child: const Text('Yes, Log Out'),
        ),
        FilledButton.tonal(
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: const Text('Go back'),
        ),
      ],
    );
  }
}
