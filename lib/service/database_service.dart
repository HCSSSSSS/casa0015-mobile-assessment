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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Error: No user logged in.");
        return false;
      }

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals');

      await docRef.add({
        'food_name': foodData['food_name'],
        'calories': foodData['calories'],
        'protein': foodData['protein'],
        'carbs': foodData['carbs'],
        'fat': foodData['fat'],
        'decibel': decibel,           
        'location': location,         
        'timestamp': FieldValue.serverTimestamp(), 
      });

      debugPrint("✅ 成功存入 Firestore Cloud!");
      return true;
    } catch (e) {
      debugPrint("❌ 存入 Firestore 失败: $e");
      return false;
    }
  }

  // 核心功能：根据日期从云端读取该日所有餐食的总热量
  static Future<int> getConsumedCaloriesForDate(DateTime date) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      // 1. 计算当天的起始时间戳和结束时间戳
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // 2. 执行 Firestore 查询，过滤出该范围内的记录
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      // 3. 累加所有查询到的卡路里
      int total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['calories'] as num).toInt();
      }

      return total;
    } catch (e) {
      debugPrint("❌ 读取云端热量失败: $e");
      return 0;
    }
  }
}
