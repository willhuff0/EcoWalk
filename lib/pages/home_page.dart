import 'package:eco_walk/api.dart';
import 'package:eco_walk/main.dart';
import 'package:eco_walk/pages/walk_page.dart';
import 'package:eco_walk/widgets/drawer.dart';
import 'package:eco_walk/widgets/history_widget.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class HomePage extends StatelessWidget {
  final AppState appState;

  const HomePage({super.key, required this.appState});

  void _startNewWalkButton(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => WalkPage(appState: appState)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ESDrawer(appState: appState),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            leading: _DrawerIconButton(),
            title: const Text(appName),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(14.0),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome, ${appState.esUser.name}!',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 14.0),
                      FilledButton.tonalIcon(
                        onPressed: () => _startNewWalkButton(context),
                        label: Text('Start a new walk'),
                        icon: const Icon(BoxIcons.bx_walk),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(left: 14.0, right: 14.0, bottom: 8.0),
            sliver: SliverToBoxAdapter(
              child: Text('History', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          SliverToBoxAdapter(child: HistoryListWidget(appState: appState)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewWalkButton(context),
        label: Text('Start a new walk'),
        icon: const Icon(BoxIcons.bx_walk),
      ),
    );
  }
}

class _DrawerIconButton extends StatelessWidget {
  const _DrawerIconButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        Scaffold.of(context).openDrawer();
      },
      icon: const Icon(BoxIcons.bx_menu_alt_left),
    );
  }
}
