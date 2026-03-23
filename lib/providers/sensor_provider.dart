import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../service/database_service.dart';

class SensorProvider with ChangeNotifier {
  // 物理环境传感器数据
  double _decibel = 0.0;
  String _location = "Locating...";
  bool _isPermissionGranted = false;

  // 用户健康数据
  int _totalCaloriesTarget = 2000; // 默认值，但稍后会被云端数据覆盖
  int _consumedCalories = 0;

  // 供外部读取的 Getter
  double get decibel => _decibel;
  String get location => _location;
  bool get isPermissionGranted => _isPermissionGranted;

  int get totalCaloriesTarget => _totalCaloriesTarget;
  int get consumedCalories => _consumedCalories;
  // 核心逻辑：计算剩余卡路里，确保不会变成负数
  int get remainingCalories => (_totalCaloriesTarget - _consumedCalories).clamp(0, _totalCaloriesTarget);

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription<Position>? _locationSubscription;

  SensorProvider() {
    initSensors();
    _fetchUserPreferences(); // 初始化时，自动去云端拉取用户的设置！
  }

  // --- 数据库交互逻辑 ---

  // 核心升级：从云端拉取用户的专属设置（如他们自己设定的目标热量）
  Future<void> _fetchUserPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('target_calories')) {
          // 如果云端有数据，覆盖默认的 2000
          _totalCaloriesTarget = (doc.data()!['target_calories'] as num).toInt();
          notifyListeners();
          debugPrint("⚙️ 从云端同步了目标热量: $_totalCaloriesTarget Kcal");
        }
      } catch (e) {
        debugPrint("拉取用户偏好失败: $e");
      }
    }
  }

  // 供设置页面调用，修改内存中的热量目标（云端写入逻辑在 SettingsScreen 已经做过了）
  void updateTargetCalories(int newTarget) {
    if (newTarget > 0) {
      _totalCaloriesTarget = newTarget;
      notifyListeners();
    }
  }

  // 刷新特定日期的热量数据（从 Firestore 读取，日历点击时触发）
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

  // 记录刚刚吃下的食物（拍照后临时增加，等待下次从云端拉取覆盖）
  void logMeal(int calories) {
    _consumedCalories += calories;
    notifyListeners();
  }

  // --- 物理传感器交互逻辑 ---

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