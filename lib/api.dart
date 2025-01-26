import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_walk/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

final findPointOfInterestUri = useEmulators ? 'http://10.0.2.2:5001/eco-step-walk/us-central1/findPointOfInterest' : 'https://findpointofinterest-7y4yyg2daa-uc.a.run.app';
final generateWalkNameUri = useEmulators ? 'http://10.0.2.2:5001/eco-step-walk/us-central1/generateWalkName' : 'https://generatewalkname-7y4yyg2daa-uc.a.run.app';

typedef FirestoreMap = Map<String, dynamic>;
typedef FirestoreDoc = DocumentSnapshot<FirestoreMap>;

class AppState {
  final ESUser esUser;

  final SharedPreferencesWithCache prefs;

  ESWalk? currentWalk;

  AppState({
    required this.esUser,
    required this.prefs,
  });
}

Future<void> apiLogOut() async {
  if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
    try {
      await apiDeleteUser(FirebaseAuth.instance.currentUser!.uid);
      await FirebaseAuth.instance.currentUser!.delete();
    } catch (_) {}
  }
  await FirebaseAuth.instance.signOut();
}

// API - User

final Map<String, ESUser> _userCache = {};

ESUser? apiGetCachedUser(String userKey) => _userCache[userKey];

Future<ESUser?> apiGetUser(String userKey) async {
  final cached = apiGetCachedUser(userKey);
  if (cached != null) return cached;

  final snapshot = await FirebaseFirestore.instance.collection('users').doc(userKey).get();
  if (!snapshot.exists) return null;
  return _userCache[userKey] = ESUser.fromSnapshot(snapshot);
}

Future<ESUser> apiCreateUser(String userKey, String name, Uint8List? iconBytes) async {
  bool hasIcon = false;
  if (iconBytes != null) {
    final compressedBytes = await compute(_compressImage, iconBytes);
    if (compressedBytes != null) {
      await FirebaseStorage.instance.ref('users/$userKey/icon.jpg').putData(compressedBytes);
      hasIcon = true;
    }
  }

  await FirebaseFirestore.instance.collection('users').doc(userKey).set({
    'name': name,
    if (hasIcon) 'hasIcon': true,
    'memberSince': FieldValue.serverTimestamp(),
  });

  return ESUser(
    key: userKey,
    name: name,
    hasIcon: hasIcon,
    memberSince: DateTime.now(),
  );
}

String apiGetUserIconUrl(String userKey) => 'gs://eco-step-walk.appspot.com/users/$userKey/icon.jpg';

FirebaseImageProvider apiGetUserIcon(String userKey) => FirebaseImageProvider(FirebaseUrl(apiGetUserIconUrl(userKey)));

Future<void> apiDeleteUser(String userKey) async {
  await FirebaseFirestore.instance.collection('users').doc(userKey).delete();
}

// API - Points of Interest

Future<PointOfInterest?> apiFindPointOfInterest(Position from, double radius) async {
  print('Finding point of interest at ${from.lat}, ${from.lng} with radius $radius');
  try {
    final response = await http.post(Uri.parse(findPointOfInterestUri), body: {
      'lat': from.lat.toString(),
      'lon': from.lng.toString(),
      'radius': radius.toString(),
    });
    return response.statusCode == 200 ? PointOfInterest.fromJson(jsonDecode(response.body)) : null;
  } catch (e) {
    print('Error finding point of interest: $e');
    return null;
  }
}

// APIs - Walks

final Map<String, ESWalk> _walkCache = {};

ESWalk? apiGetCachedWalk(String walkKey) => _walkCache[walkKey];

Future<ESWalk?> apiGetWalk(AppState appState, String walkKey) async {
  final cached = apiGetCachedWalk(walkKey);
  if (cached != null) return cached;

  final snapshot = await FirebaseFirestore.instance.collection('users').doc(appState.esUser.key).collection('walks').doc(walkKey).get();
  if (!snapshot.exists) return null;
  return _walkCache[walkKey] = ESWalk.fromSnapshot(snapshot);
}

ESWalk apiCreateWalkNoPublish(AppState appState) {
  final walkKey = FirebaseFirestore.instance.collection('users').doc(appState.esUser.key).collection('walks').doc().id;
  return ESWalk(
    key: walkKey,
    name: '',
    date: DateTime.now(),
    points: [],
    pois: [],
  );
}

Future<String?> apiGetWalkName(ESWalk walk) async {
  try {
    final response = await http.post(Uri.parse(generateWalkNameUri), body: jsonEncode(walk.toMapForOpenAI()));
    return response.statusCode == 200 ? jsonDecode(response.body)['name'] : null;
  } catch (e) {
    print('Error getting walk name: $e');
    return null;
  }
}

Future<void> apiPublishWalk(AppState appState, ESWalk walk) async {
  await FirebaseFirestore.instance.collection('users').doc(appState.esUser.key).collection('walks').doc(walk.key).set({
    'name': walk.name,
    'date': Timestamp.fromDate(walk.date),
    'points': walk.points.map((p) => {'lat': p.lat, 'lon': p.lng}).toList(),
    'pois': walk.pois
        .map((poi) => {
              'geopoint': {'lat': poi.position.lat, 'lon': poi.position.lng},
              'name': poi.name,
              'description': poi.description,
              'interesting_fact': poi.funFact,
            })
        .toList(),
  });
}

Future<List<ESWalk>> apiGetWalks(AppState appState) {
  return FirebaseFirestore.instance.collection('users').doc(appState.esUser.key).collection('walks').get().then((query) {
    return query.docs.map((doc) => ESWalk.fromSnapshot(doc)).toList();
  });
}

Future<void> apiDeleteWalk(AppState appState, ESWalk walk) async {
  await FirebaseFirestore.instance.collection('users').doc(appState.esUser.key).collection('walks').doc(walk.key).delete();
}

// Model

class ESUser {
  final String key;

  String name;
  bool hasIcon;
  final DateTime memberSince;

  ESUser({
    required this.key,
    required this.name,
    required this.hasIcon,
    required this.memberSince,
  });

  factory ESUser.fromMap(String key, FirestoreMap map) => ESUser(
        key: key,
        name: map['name'],
        hasIcon: map['hasIcon'] == true,
        memberSince: (map['memberSince'] as Timestamp).toDate(),
      );

  factory ESUser.fromSnapshot(FirestoreDoc doc) => ESUser.fromMap(doc.id, doc.data()!);
}

class ESWalk {
  final String key;

  String name;
  DateTime date;
  List<Position> points;

  final List<PointOfInterest> pois;

  ESWalk({
    required this.key,
    required this.name,
    required this.date,
    required this.points,
    required this.pois,
  });

  factory ESWalk.fromMap(String key, FirestoreMap map) => ESWalk(
        key: key,
        name: map['name'] ?? 'Unnamed Walk',
        date: (map['date'] as Timestamp).toDate(),
        points: map['points'].map<Position>((p) => Position(p['lon'], p['lat'])).toList(),
        pois: map['pois'].map<PointOfInterest>((poi) => PointOfInterest.fromJson(poi)).toList(),
      );

  factory ESWalk.fromSnapshot(FirestoreDoc doc) => ESWalk.fromMap(doc.id, doc.data()!);

  Map<String, dynamic> toMapForOpenAI() => {
        'name': name,
        'date': date.toIso8601String(),
        'points': points.map((p) => {'lat': p.lat, 'lon': p.lng}).toList(),
        'points_of_interest': pois
            .map((poi) => {
                  'geopoint': {'lat': poi.position.lat, 'lon': poi.position.lng},
                  'name': poi.name,
                  'description': poi.description,
                  'interesting_fact': poi.funFact,
                })
            .toList(),
      };
}

class PointOfInterest {
  final Position position;
  final String name;
  final String description;
  final String funFact;

  PointOfInterest({
    required this.position,
    required this.name,
    required this.description,
    required this.funFact,
  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) => PointOfInterest(
        position: Position(json['geopoint']['lon'], json['geopoint']['lat']),
        name: json['name'],
        description: json['description'],
        funFact: json['interesting_fact'],
      );
}

//

Uint8List? _compressImage(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  image = img.copyResizeCropSquare(image, size: 256, interpolation: img.Interpolation.cubic);
  return img.encodeJpg(image, quality: 70);
}
