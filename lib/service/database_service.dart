import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  // 核心功能：将一顿饭的所有环境与营养数据打包存入云端
  static Future<bool> saveMealToCloud({
    required Map<String, dynamic> foodData,
    required double decibel,
    required String location,
  }) async {
    try {
      // 1. 获取当前登录的用户
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Error: No user logged in.");
        return false;
      }

      // 2. 定位到该用户的专属数据库路径: users/{uid}/meals
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals');

      // 3. 将 AI 数据和传感器数据打包成 JSON 存入云端
      await docRef.add({
        'food_name': foodData['food_name'],
        'calories': foodData['calories'],
        'protein': foodData['protein'],
        'carbs': foodData['carbs'],
        'fat': foodData['fat'],
        'decibel': decibel,           // 物理环境：噪音
        'location': location,         // 物理环境：GPS坐标
        'timestamp': FieldValue.serverTimestamp(), // 绝对准确的云端时间戳
      });

      debugPrint("✅ 成功存入 Firestore Cloud!");
      return true;
    } catch (e) {
      debugPrint("❌ 存入 Firestore 失败: $e");
      return false;
    }
  }
}