import 'package:flutter/material.dart';

class SensorProvider extends ChangeNotifier {
  double decibel = 0.0;
  String location = "Locating...";

  // 饮食数据状态
  int totalCaloriesTarget = 2000;
  int consumedCalories = 0;

  int get remainingCalories => (totalCaloriesTarget - consumedCalories).clamp(0, totalCaloriesTarget);

  void updateNoise(double db) {
    decibel = db;
    notifyListeners();
  }

  void updateLocation(String loc) {
    location = loc;
    notifyListeners();
  }

  // 记录食物卡路里并刷新 UI
  void logMeal(int calories) {
    consumedCalories += calories;
    notifyListeners();
  }
}