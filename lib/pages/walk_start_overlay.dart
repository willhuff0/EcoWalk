import 'package:flutter/material.dart';

class WalkStartOverlay extends StatefulWidget {
  const WalkStartOverlay({super.key});

  @override
  State<WalkStartOverlay> createState() => _WalkStartOverlayState();
}

class _WalkStartOverlayState extends State<WalkStartOverlay> {
  late final PageController _pageController;

  var _shrink = false;

  @override
  void initState() {
    _pageController = PageController();
    _animate();
    super.initState();
  }

  void _animate() async {
    await Future.delayed(Duration(milliseconds: 1400));
    _pageController.nextPage(duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    await Future.delayed(Duration(milliseconds: 1000));
    _pageController.nextPage(duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    await Future.delayed(Duration(milliseconds: 1000));
    setState(() => _shrink = true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Align(
        alignment: Alignment.topCenter,
        child: AnimatedOpacity(
          opacity: _shrink ? 0.0 : 1.0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeIn,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 600),
            curve: Curves.easeInOutCubicEmphasized,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.inversePrimary,
              borderRadius: _shrink ? BorderRadius.circular(10000.0) : null,
            ),
            constraints: _shrink
                ? BoxConstraints(
                    maxWidth: 100.0,
                    maxHeight: 100.0,
                    minHeight: 100.0,
                    minWidth: 100.0,
                  )
                : constraints,
            child: PageView(
              physics: NeverScrollableScrollPhysics(),
              controller: _pageController,
              children: [
                Center(child: Text('Ready', style: Theme.of(context).textTheme.headlineLarge)),
                Center(child: Text('Set', style: Theme.of(context).textTheme.headlineLarge)),
                Center(child: Text('Walk', style: Theme.of(context).textTheme.headlineLarge)),
              ],
            ),
          ),
        ),
      );
    });
  }
}
