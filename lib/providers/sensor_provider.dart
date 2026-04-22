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

  bool _isInitializing = false;
  bool _hasInitialized = false;

  SensorProvider() {
    _fetchUserPreferences(); // Fetch user settings from cloud on initialization
    // initSensors is no longer called in constructor
  }

  // --- Database Interaction Logic ---

  Future<void> _fetchUserPreferences() async {
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
          _totalCaloriesTarget = (doc.data()!['target_calories'] as num).toInt();
          notifyListeners();
          debugPrint("⚙️ Synced target calories from cloud: $_totalCaloriesTarget Kcal");
        }
      } catch (e) {
        debugPrint("Failed to fetch user preferences: $e");
      }
    }
  }

  void updateTargetCalories(int newTarget) {
    if (newTarget > 0) {
      _totalCaloriesTarget = newTarget;
      notifyListeners();
    }
  }

  Future<void> refreshDataForDate(DateTime date) async {
    try {
      int cloudCalories = await DatabaseService.getConsumedCaloriesForDate(date);
      _consumedCalories = cloudCalories;

      final nutrients = await DatabaseService.getNutrientsForDate(date);
      _protein = nutrients['protein']!;
      _carbs = nutrients['carbs']!;
      _fat = nutrients['fat']!;

      notifyListeners();
    } catch (e) {
      debugPrint("Failed to refresh data: $e");
    }
  }

  void logMeal(int calories) {
    _consumedCalories += calories;
    notifyListeners();
  }

  Future<void> refreshOnAuthChange() async {
    _totalCaloriesTarget = 2000;
    _consumedCalories = 0;
    _protein = 0;
    _carbs = 0;
    _fat = 0;
    notifyListeners();

    // Only call initSensors if it has never been successfully initialized
    if (!_hasInitialized) {
      await initSensors();
    }

    await _fetchUserPreferences();
    await refreshDataForDate(DateTime.now());
  }

  // --- Physical Sensor Interaction Logic ---

  Future<void> initSensors() async {
    // Prevent concurrent calls
    if (_isInitializing) {
      debugPrint("initSensors already in progress, skipping.");
      return;
    }
    _isInitializing = true;

    try {
      // Check current status first to avoid redundant popups if already granted
      final micStatus = await Permission.microphone.status;
      final locStatus = await Permission.location.status;

      Map<Permission, PermissionStatus> statuses;
      if (micStatus.isGranted && locStatus.isGranted) {
        statuses = {
          Permission.microphone: micStatus,
          Permission.location: locStatus,
        };
      } else {
        statuses = await [
          Permission.microphone,
          Permission.location,
        ].request();
      }

      if (statuses[Permission.microphone]!.isGranted &&
          statuses[Permission.location]!.isGranted) {
        _isPermissionGranted = true;
        await Future.delayed(const Duration(milliseconds: 300));
        _startNoiseListening();
        _startLocationListening();
      } else {
        _isPermissionGranted = false;
        _location = "Permission Denied";
      }
      _hasInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint("initSensors error: $e");
      // Even if permission request fails, try starting streams directly - system may have authorized
      try {
        _startNoiseListening();
        _startLocationListening();
        _isPermissionGranted = true;
        notifyListeners();
      } catch (e2) {
        debugPrint("Fallback stream start failed: $e2");
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _startNoiseListening() {
    if (_noiseSubscription != null) return;
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
    if (_locationSubscription != null) return;
    try {
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) async {
        _location = "${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}";
        notifyListeners();

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
