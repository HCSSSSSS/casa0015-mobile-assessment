import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../service/database_service.dart';

class SensorProvider with ChangeNotifier {
  // 物理环境传感器数据
  double _decibel = 0.0;
  String _location = "Locating...";
  bool _isPermissionGranted = false;

  // 用户健康数据
  int _totalCaloriesTarget = 2000; 
  int _consumedCalories = 0;       

  double get decibel => _decibel;
  String get location => _location;
  bool get isPermissionGranted => _isPermissionGranted;
  
  int get totalCaloriesTarget => _totalCaloriesTarget;
  int get consumedCalories => _consumedCalories;
  int get remainingCalories => (_totalCaloriesTarget - _consumedCalories).clamp(0, _totalCaloriesTarget);

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription<Position>? _locationSubscription;

  SensorProvider() {
    initSensors();
  }

  // 核心功能：刷新特定日期的热量数据（从 Firestore 读取）
  Future<void> refreshDataForDate(DateTime date) async {
    try {
      int cloudCalories = await DatabaseService.getConsumedCaloriesForDate(date);
      _consumedCalories = cloudCalories;
      notifyListeners();
      debugPrint("🔄 已刷新日期 ${date.toIso8601String()} 的热量: $cloudCalories Kcal");
    } catch (e) {
      debugPrint("刷新热量失败: $e");
    }
  }

  // 兼容旧方法的逻辑（如果需要手动增加）
  void logMeal(int calories) {
    _consumedCalories += calories;
    notifyListeners();
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
