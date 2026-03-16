import 'package:flutter/material.dart';
import '../service/database_service.dart';

class SensorProvider extends ChangeNotifier {
  // 物理环境传感器数据
  double decibel = 0.0;
  String location = "Locating...";

  // 用户健康数据
  int totalCaloriesTarget = 2000; // 每日目标
  int consumedCalories = 0;       // 今日已摄入（从云端读取）

  // 计算剩余配额
  int get remainingCalories => (totalCaloriesTarget - consumedCalories).clamp(0, totalCaloriesTarget);

  void updateNoise(double db) {
    decibel = db;
    notifyListeners();
  }

  void updateLocation(String loc) {
    location = loc;
    notifyListeners();
  }

  // 核心功能：切换日历日期时调用，从 Firestore 读取当天总热量并刷新圆环 UI
  Future<void> refreshDataForDate(DateTime date) async {
    // 1. 去云端计算这天的总热量
    int cloudCalories = await DatabaseService.getConsumedCaloriesForDate(date);

    // 2. 更新本地状态并通知圆环重新绘制
    consumedCalories = cloudCalories;
    notifyListeners();
  }
}