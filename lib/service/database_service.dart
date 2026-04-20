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

  // 核心功能：根据日期从云端读取该日所有餐食的营养成分（蛋白质、碳水、脂肪）
  static Future<Map<String, double>> getNutrientsForDate(DateTime date) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'protein': 0, 'carbs': 0, 'fat': 0};

      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      double protein = 0, carbs = 0, fat = 0;
      for (var doc in snapshot.docs) {
        protein += (doc.data()['protein'] as num? ?? 0).toDouble();
        carbs += (doc.data()['carbs'] as num? ?? 0).toDouble();
        fat += (doc.data()['fat'] as num? ?? 0).toDouble();
      }

      return {'protein': protein, 'carbs': carbs, 'fat': fat};
    } catch (e) {
      debugPrint("读取营养数据失败: $e");
      return {'protein': 0, 'carbs': 0, 'fat': 0};
    }
  }

  // 核心功能：按月批量读取热量数据
  static Future<Map<String, int>> getMonthlyCalories(int year, int month) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      DateTime start = DateTime(year, month, 1);
      DateTime end = DateTime(year, month + 1, 1);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThan: end)
          .get();

      Map<String, int> result = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final ts = data['timestamp'];
        if (ts is Timestamp) {
          final date = ts.toDate();
          final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          result[key] = (result[key] ?? 0) + (data['calories'] as num? ?? 0).toInt();
        }
      }
      return result;
    } catch (e) {
      debugPrint("读取月度数据失败: $e");
      return {};
    }
  }
}
