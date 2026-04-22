import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import '../service/database_service.dart';

class SensorProvider with ChangeNotifier {
  // Physical environment sensor data
  double _decibel = 0.0;
  String _location = "Locating...";
  bool _isPermissionGranted = false;

  // User health data
  int _totalCaloriesTarget = 2000; // Default value, will be overwritten by cloud data
  int _consumedCalories = 0;
  double _protein = 0;
  double _carbs = 0;
  double _fat = 0;

  // Getters for external access
  double get decibel => _decibel;
  String get location => _location;
  bool get isPermissionGranted => _isPermissionGranted;

  int get totalCaloriesTarget => _totalCaloriesTarget;
  int get consumedCalories => _consumedCalories;
  double get protein => _protein;
  double get carbs => _carbs;
  double get fat => _fat;
  
  // Core logic: Calculate remaining calories, ensure it doesn't go negative
  int get remainingCalories => (_totalCaloriesTarget - _consumedCalories).clamp(0, _totalCaloriesTarget);

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription<Position>? _locationSubscription;
  DateTime _lastNoiseUpdate = DateTime.now();

  SensorProvider() {
    initSensors();
    _fetchUserPreferences(); // Fetch user settings from cloud on initialization
  }

  // --- Database Interaction Logic ---

  // Core upgrade: Pull user-specific settings (e.g., their self-defined calorie target) from cloud
  Future<void> _fetchUserPreferences() async {
    // Reset to default values first
    _totalCaloriesTarget = 2000;
    _consumedCalories = 0;
    _protein = 0;
    _carbs = 0;
    _fat = 0;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('target_calories')) {
          // If cloud data exists, overwrite default 2000
          _totalCaloriesTarget = (doc.data()!['target_calories'] as num).toInt();
          notifyListeners();
          debugPrint("⚙️ Synced target calories from cloud: $_totalCaloriesTarget Kcal");
        }
      } catch (e) {
        debugPrint("Failed to fetch user preferences: $e");
      }
    }
  }

  // Called by settings page to modify memory target (cloud writing logic is in SettingsScreen)
  void updateTargetCalories(int newTarget) {
    if (newTarget > 0) {
      _totalCaloriesTarget = newTarget;
      notifyListeners();
    }
  }

  // Refresh calorie data for a specific date (read from Firestore, triggered by calendar click)
  Future<void> refreshDataForDate(DateTime date) async {
    try {
      int cloudCalories = await DatabaseService.getConsumedCaloriesForDate(date);
      _consumedCalories = cloudCalories;

      final nutrients = await DatabaseService.getNutrientsForDate(date);
      _protein = nutrients['protein']!;
      _carbs = nutrients['carbs']!;
      _fat = nutrients['fat']!;

      notifyListeners();
      debugPrint("🔄 Refreshed calories for ${date.toIso8601String()}: $cloudCalories Kcal, Nutrients: $nutrients");
    } catch (e) {
      debugPrint("Failed to refresh data: $e");
    }
  }

  // Log meal just eaten (temporary increase after photo/text, waiting for next cloud pull)
  void logMeal(int calories) {
    _consumedCalories += calories;
    notifyListeners();
  }

  Future<void> refreshOnAuthChange() async {
    // Stop current sensors to prevent conflicts
    await _noiseSubscription?.cancel();
    await _locationSubscription?.cancel();

    _totalCaloriesTarget = 2000;
    _consumedCalories = 0;
    _protein = 0;
    _carbs = 0;
    _fat = 0;
    notifyListeners();

    // Re-initialize for new user
    await initSensors();
    await _fetchUserPreferences();
    await refreshDataForDate(DateTime.now());
  }

  // --- Physical Sensor Interaction Logic ---

  Future<void> initSensors() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.location,
    ].request();

    if (statuses[Permission.microphone]!.isGranted &&
        statuses[Permission.location]!.isGranted) {
      _isPermissionGranted = true;
      _startNoiseListening();
      _startLocationListening();
    } else {
      _isPermissionGranted = false;
      _location = "Permission Denied";
    }
    notifyListeners();
  }

  void _startNoiseListening() {
    try {
      _noiseMeter = NoiseMeter();
      _noiseSubscription = _noiseMeter?.noise.listen((reading) {
        final now = DateTime.now();
        if (now.difference(_lastNoiseUpdate).inMilliseconds > 1000) {
          _decibel = reading.meanDecibel;
          _lastNoiseUpdate = now;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint("Noise Meter Error: $e");
    }
  }

  void _startLocationListening() {
    try {
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) async {
        _location = "${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}";
        notifyListeners();

        // Reverse geocoding
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _location = "${place.street ?? ''}, ${place.locality ?? ''}".trim();
            if (_location == ',') {
              _location = "${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}";
            }
            notifyListeners();
          }
        } catch (e) {
          debugPrint("Geocoding error: $e");
        }
      });
    } catch (e) {
      debugPrint("GPS Error: $e");
      _location = "GPS Error";
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
