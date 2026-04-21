import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  // Core functionality: Package and save all environmental and nutritional data to cloud
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

      debugPrint("✅ Successfully saved to Firestore Cloud!");
      return true;
    } catch (e) {
      debugPrint("❌ Failed to save to Firestore: $e");
      return false;
    }
  }

  // Core functionality: Read total calories for a given date from cloud
  static Future<int> getConsumedCaloriesForDate(DateTime date) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      // 1. Calculate start and end timestamps for the day
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // 2. Execute Firestore query, filtering records within the range
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      // 3. Accumulate all queried calories
      int total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['calories'] as num).toInt();
      }

      return total;
    } catch (e) {
      debugPrint("❌ Failed to read cloud calories: $e");
      return 0;
    }
  }

  // Core functionality: Read nutritional components (protein, carbs, fat) for a given date from cloud
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
      debugPrint("Failed to read nutrient data: $e");
      return {'protein': 0, 'carbs': 0, 'fat': 0};
    }
  }

  // Core functionality: Batch read calorie data by month
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
      debugPrint("Failed to read monthly data: $e");
      return {};
    }
  }
}
