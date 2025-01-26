import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:eco_walk/api.dart';
import 'package:eco_walk/firebase_options.dart';
import 'package:eco_walk/pages/error_page.dart';
import 'package:eco_walk/pages/home_page.dart';
import 'package:eco_walk/pages/landing_page.dart';
import 'package:eco_walk/pages/loading_page.dart';
import 'package:eco_walk/pages/location_permission_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const appName = 'EcoWalk';

const useEmulators = false && kDebugMode;
const fakeSignIn = true && useEmulators;

const emulatorAddress = '127.0.0.1';

const _version = '1.0.0';
const version = kDebugMode ? '$_version (debug)' : _version;

const _uploadGoogleProfilePictureOnFirstSignIn = false;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardTheme(
          elevation: 1.0,
          surfaceTintColor: Colors.green,
          shadowColor: Colors.transparent,
        ),
      ),
      // darkTheme: ThemeData(
      //   colorScheme: ColorScheme.fromSeed(
      //     seedColor: Colors.green,
      //     brightness: Brightness.dark,
      //   ),
      //   useMaterial3: true,
      //   cardTheme: const CardTheme(
      //     elevation: 0.5,
      //   ),
      // ),
      home: _InitializerWidget(),
    );
  }
}

class _InitializerWidget extends StatefulWidget {
  const _InitializerWidget();

  @override
  State<_InitializerWidget> createState() => _InitializerWidgetState();
}

class _InitializerWidgetState extends State<_InitializerWidget> {
  var _loading = true;

  @override
  void initState() {
    _initialize().then((_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    });
    super.initState();
  }

  Future<void> _initialize() async {
    // ==== Mapbox ====
    MapboxOptions.setAccessToken('pk.eyJ1Ijoid2lsbGh1ZmYiLCJhIjoiY2w4eDlxYWU5MDRtZDN2bnc0aXAzZ2hlcCJ9.2j6q2Zt5fI6BmvziWpZGWA');

    // ==== Firebase ====
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator(emulatorAddress, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorAddress, 8080);
      await FirebaseStorage.instance.useStorageEmulator(emulatorAddress, 9199);
      FirebaseFunctions.instance.useFunctionsEmulator(emulatorAddress, 5001);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading ? LoadingPage() : _UserPreloaderPage();
  }
}

class _UserPreloaderPage extends StatefulWidget {
  const _UserPreloaderPage();

  @override
  State<_UserPreloaderPage> createState() => _UserPreloaderPageState();
}

class _UserPreloaderPageState extends State<_UserPreloaderPage> {
  late final StreamSubscription _authStateChangesSubscription;
  late final StreamSubscription _onTokenRefreshSubscription;

  var _loading = true;
  var _fetching = false;

  ESUser? _esUser;

  @override
  void initState() {
    _authStateChangesSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _fetch(user);
      } else {
        setState(() {
          _esUser = null;
          _loading = false;
        });
      }
    });

    // rePreloadUser = () {
    //   if (mounted) {
    //     setState(() => _loading = true);
    //     _fetch(FirebaseAuth.instance.currentUser!);
    //   }
    // };
    super.initState();
  }

  Future<void> _fetch(User user) async {
    while (_fetching) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _fetching = true;
    try {
      final userKey = user.uid;

      var esUser = await apiGetUser(userKey).timeout(const Duration(seconds: 6));
      esUser ??= await _firstSignIn();

      // if (_fcmToken != null && _fcmToken != userData.fcmToken) {
      //   await apiSetFCMToken(userData, _fcmToken!);
      // }

      // final idToken = await user.getIdTokenResult();
      // final creator = idToken.claims?['creator'] ?? false;

      if (mounted) {
        setState(() {
          _esUser = esUser;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _esUser = null;
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  Future<ESUser> _firstSignIn() async {
    final user = FirebaseAuth.instance.currentUser!;

    String name = user.displayName ?? 'Anonymous';
    Uint8List? iconBytes;
    if (_uploadGoogleProfilePictureOnFirstSignIn && user.photoURL != null) {
      final uri = Uri.parse(user.photoURL!);
      final response = await http.get(uri);
      iconBytes = response.bodyBytes;
    }

    return await apiCreateUser(user.uid, name, iconBytes);
  }

  @override
  void dispose() {
    _authStateChangesSubscription.cancel();
    _onTokenRefreshSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const LoadingPage()
        : _esUser != null
            ? AppStateProvider(
                esUser: _esUser!,
              )
            : const LandingPage();
  }
}

class AppStateProvider extends StatefulWidget {
  final ESUser esUser;

  const AppStateProvider({super.key, required this.esUser});

  @override
  State<AppStateProvider> createState() => _AppStateProviderState();
}

class _AppStateProviderState extends State<AppStateProvider> {
  AppState? _appState;

  @override
  void initState() {
    _load();
    super.initState();
  }

  void _load() async {
    final prefs = await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());

    if (mounted) {
      setState(() {
        _appState = AppState(
          esUser: widget.esUser,
          prefs: prefs,
        );
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _appState == null ? const LoadingPage() : _EnsureLocationPermissionPage(appState: _appState!);
  }
}

late Future<void> Function() checkLocationPermission;

class _EnsureLocationPermissionPage extends StatefulWidget {
  final AppState appState;

  const _EnsureLocationPermissionPage({required this.appState});

  @override
  State<_EnsureLocationPermissionPage> createState() => _EnsureLocationPermissionPageState();
}

class _EnsureLocationPermissionPageState extends State<_EnsureLocationPermissionPage> {
  var _loading = true;
  var _fetching = false;
  var _needsRequestPermission = false;

  String? _error;

  @override
  void initState() {
    checkLocationPermission = () async {
      if (mounted) {
        await _check();
      }
    };
    _check();
    super.initState();
  }

  Future<void> _check() async {
    if (_fetching) return;
    try {
      _fetching = true;

      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        _error = '$appName requires access to your location while the app is in use. Location services are not enabled or supported on this device.';
        _needsRequestPermission = false;
        return;
      }

      var permission = await geo.Geolocator.checkPermission();

      switch (permission) {
        case geo.LocationPermission.denied:
          _needsRequestPermission = true;
          return;
        case geo.LocationPermission.deniedForever:
          _error = '$appName requires access to your location while the app is in use. Enable location access for $appName in your device settings.';
          _needsRequestPermission = false;
          return;
        case geo.LocationPermission.unableToDetermine:
          _error = '$appName requires access to your location while the app is in use. Location services are not enabled or supported on this device.';
          _needsRequestPermission = false;
          return;
        case geo.LocationPermission.whileInUse:
          _needsRequestPermission = false;
          break;
        case geo.LocationPermission.always:
          _needsRequestPermission = false;
          break;
      }

      _error = null;
    } finally {
      _fetching = false;
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const LoadingPage()
        : _needsRequestPermission
            ? const LocationPermissionPage()
            : _error != null
                ? ErrorPage(message: _error!)
                : HomePage(appState: widget.appState);
  }
}
