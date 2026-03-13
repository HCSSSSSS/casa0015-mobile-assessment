import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

class SensorProvider with ChangeNotifier {
  double _decibel = 0.0;
  String _location = "Locating...";
  bool _isPermissionGranted = false;

  double get decibel => _decibel;
  String get location => _location;
  bool get isPermissionGranted => _isPermissionGranted;

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription<Position>? _locationSubscription;

  SensorProvider() {
    initSensors();
  }

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
        _decibel = reading.meanDecibel;
        notifyListeners();
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
      ).listen((Position position) {
        _location = "${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}";
        notifyListeners();
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
