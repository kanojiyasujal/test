

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

import 'listofall_location.dart';
import 'radarsetting.dart';

class SearchPlacesScreen extends StatefulWidget {
  const SearchPlacesScreen({Key? key}) : super(key: key);

  @override
  State<SearchPlacesScreen> createState() => _SearchPlacesScreenState();
}

const kGoogleApiKey = 'AIzaSyDSiCgGPGMrRY1HZ5cQuMAiYWK4NTJhPuI';

class _SearchPlacesScreenState extends State<SearchPlacesScreen> {
  static const CameraPosition initialCameraPosition =
      CameraPosition(target: LatLng(37.42796, -122.08574), zoom: 14.0);

  final homeScaffoldKey = GlobalKey<ScaffoldState>();
  Set<Marker> markersList = {};
  Set<Circle> radarCircles = {};
  late GoogleMapController googleMapController;
  final Mode _mode = Mode.overlay;
  Prediction? _selectedPrediction;
  double radarRange = 1000; // Default radar range in meters
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    _openDoNotDisturbSettings();
    _showCurrentLocation();
    _checkForSavedLocations();
    
    }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: homeScaffoldKey,
      appBar: AppBar(
        title: const Text("Google Search Places"),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        children: [
          SpeedDialChild(
            child: Icon(Icons.save),
            label: 'Save Location',
            onTap: () {
              _handleSaveLocation();
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.my_location),
            label: 'Current Location',
            onTap: () {
              _showCurrentLocation();
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.settings),
            label: 'Radar Setting',
            onTap: () async {
              final updatedRadarRange = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RadarSettingsPage(
                    initialRadarRange: radarRange,
                  ),
                ),
              );
              if (updatedRadarRange != null) {
                setState(() {
                  radarRange = updatedRadarRange;
                });

                _updateRadarCircles();
              }
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.list),
            label: 'List of Locations',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationListPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (currentLocation == null) {
            return true;
          } else {
            setState(() {
              currentLocation = null;
            });
            _showCurrentLocation();
            return false;
          }
        },
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: initialCameraPosition,
              markers: markersList,
              circles: radarCircles,
              mapType: MapType.normal,
              onMapCreated: (GoogleMapController controller) {
                googleMapController = controller;
              },
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _handlePressButton(),
                  icon: Icon(Icons.search),
                  label: const Text("Search Places"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePressButton() async {
    _selectedPrediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      onError: onError,
      mode: _mode,
      language: 'en',
      strictbounds: false,
      types: [""],
      decoration: InputDecoration(
        hintText: 'Search',
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
      components: [
        Component(Component.country, "ind"),
        Component(Component.country, "usa"),
      ],
    );

    if (_selectedPrediction != null) {
      displayPrediction(_selectedPrediction!, homeScaffoldKey.currentState);
    }
  }

  void onError(PlacesAutocompleteResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: Text(response.errorMessage ?? 'Error'),
      ),
    );
  }

  Future<void> displayPrediction(Prediction p, ScaffoldState? currentState) async {
    GoogleMapsPlaces places = GoogleMapsPlaces(
      apiKey: kGoogleApiKey,
    );

    PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);

    final lat = detail.result.geometry!.location.lat;
    final lng = detail.result.geometry!.location.lng;

    currentLocation = LatLng(lat, lng);

    markersList.clear();
    markersList.add(
      Marker(
        markerId: const MarkerId("0"),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(title: detail.result.name),
      ),
    );

    setState(() {});

    googleMapController.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.0),
    );

    _updateRadarCircles();
  }

Future<void> _handleSaveLocation() async {
  if (currentLocation != null) {
    final name = _selectedPrediction?.description ?? 'Current Location';
    final address =
        _selectedPrediction?.structuredFormatting?.secondaryText ?? '';

    // Check if the location already exists in Firestore
    bool locationExists = await _checkIfLocationExists(currentLocation!);

    if (locationExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location already exists.'),
        ),
      );
    } else {
      try {
        // Save radar range along with location data
        await FirebaseFirestore.instance.collection('location').add({
          'lat': currentLocation!.latitude,
          'lng': currentLocation!.longitude,
          'name': name,
          'address': address,
          'radarRange': radarRange, // Save radar range in Firestore
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location saved successfully.'),
          ),
        );

        // Trigger the updateSoundModeBasedOnLocation function after saving the location
        updateSoundModeBasedOnLocation();
      } catch (e) {
        print('Error saving location: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save location.'),
          ),
        );
      }
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No location to save. Please search for a location.'),
      ),
    );
  }
}

  Future<bool> _checkIfLocationExists(LatLng location) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('location')
          .where('lat', isEqualTo: location.latitude)
          .where('lng', isEqualTo: location.longitude)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if location exists: $e');
      return false;
    }
  }

  Future<void> _showCurrentLocation() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Set _selectedPrediction to null when using "Current Location" button
        _selectedPrediction = null;

        // Center the map on the user's current location
        googleMapController.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14.0,
          ),
        );

        // Add a marker for the current location
        markersList.add(
          Marker(
            markerId: MarkerId("current_location"),
            position: LatLng(position.latitude, position.longitude),
            icon: BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: "Current Location"),
          ),
        );

        setState(() {});

        // Use geocoding for reverse geocoding
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
          localeIdentifier: 'en_US',
        );

        if (placemarks.isNotEmpty) {
          final Placemark placemark = placemarks.first;
          final name = placemark.name ?? "No Name";
          final address = placemark.street ?? "No Address";

          _selectedPrediction = Prediction(description: '$name, $address');
        } else {
          _selectedPrediction = Prediction(description: "No Address Found");
        }

        _updateRadarCircles();

        setState(() {});

        // Save current location as a separate variable
        currentLocation = LatLng(position.latitude, position.longitude);
      } catch (e) {
        print('Error getting current location: $e');
      }
    } else if (status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Location Permission Required'),
            content: Text(
              'Please grant location permission in the device settings to use this feature.',
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Open Settings'),
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
Future<void> _updateRadarCircles() async {
  radarCircles.clear();
  if (currentLocation != null) {
    radarCircles.add(
      Circle(
        circleId: CircleId('radar_circle_${currentLocation!.latitude}_${currentLocation!.longitude}'),
        center: currentLocation!,
        radius: radarRange,
        fillColor: Color.fromRGBO(0, 0, 255, 0.3),
        strokeWidth: 0,
      ),
    );
  }

  setState(() {
    updateSoundModeBasedOnLocation();
  });
}

 Future<void> updateSoundModeBasedOnLocation() async {
  try {
    QuerySnapshot querySnapshot =
        await FirebaseFirestore.instance.collection('location').get();
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    bool shouldMute = false; // Flag to track if the phone should be muted

    for (QueryDocumentSnapshot document in querySnapshot.docs) {
      double savedLat = document['lat'];
      double savedLng = document['lng'];
      double savedRadarRange = document['radarRange'];

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        savedLat,
        savedLng,
      );

      if (distance < savedRadarRange) {
        shouldMute = true; // Set the flag to mute the phone
        break; // No need to check other locations if one location is in range
      }
    }

    if (shouldMute) {
      _setSilentMode(); // Mute the phone
    } else {
      _setNormalMode(); // Unmute the phone
    }
  } catch (e) {
    print('Error updating sound mode based on location: $e');
  }
}

  RingerModeStatus _soundMode = RingerModeStatus.unknown;

  Future<void> _setNormalMode() async {
    RingerModeStatus status;

    try {
      status = await SoundMode.setSoundMode(RingerModeStatus.normal);
      setState(() {
        _soundMode = status;
      });
    } on PlatformException {
      print('Do Not Disturb access permissions required!');
    }
  }

  Future<void> _setSilentMode() async {
    RingerModeStatus status;

    try {
      status = await SoundMode.setSoundMode(RingerModeStatus.silent);

      setState(() {
        _soundMode = status;
      });
    } on PlatformException {
      print('Do Not Disturb access permissions required!');
    }
  }

  Future<void> _openDoNotDisturbSettings() async {
    bool? isGranted = await PermissionHandler.permissionsGranted;

    if (!isGranted!) {
      await PermissionHandler.openDoNotDisturbSetting();
    }
  }

  Future<void> _checkForSavedLocations() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('location').get();
    if (querySnapshot.docs.isNotEmpty) {
      for (QueryDocumentSnapshot document in querySnapshot.docs) {
        double savedLat = document['lat'];
        double savedLng = document['lng'];
        double radarRange = document['radarRange'];

        updateSoundModeBasedOnLocation();
      }
    }
  }
}

