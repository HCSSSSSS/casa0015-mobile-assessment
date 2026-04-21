import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text("My Journal", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meals')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));
          
          final meals = snapshot.data!.docs;
          if (meals.isEmpty) return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text("No meals logged yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                SizedBox(height: 8),
                Text("Tap the camera to log your first meal!", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );

          // Group by date
          Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (var doc in meals) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'];
            DateTime date;
            if (ts is Timestamp) {
              date = ts.toDate();
            } else {
              date = DateTime.now();
            }
            final key = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
            grouped.putIfAbsent(key, () => []).add(doc);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final dateKey = grouped.keys.elementAt(index);
              final dayMeals = grouped[dateKey]!;
              final totalCal = dayMeals.fold<int>(0, (total, doc) {
                final data = doc.data() as Map<String, dynamic>;
                return total + (data['calories'] as num? ?? 0).toInt();
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey)),
                        Text("$totalCal Kcal total", style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  ...dayMeals.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final ts = data['timestamp'];
                    String timeStr = "";
                    if (ts is Timestamp) {
                      final dt = ts.toDate();
                      timeStr = "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
                    }
                    return _buildMealCard(data, timeStr);
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> data, String time) {
    final double db = double.tryParse(data['decibel']?.toString() ?? '0') ?? 0;
    final Color noiseColor = db < 50 ? Colors.green : (db < 70 ? Colors.orange : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.restaurant, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['food_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 3),
                    Text("${data['calories']} Kcal", style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                    const SizedBox(width: 12),
                    Icon(Icons.graphic_eq, size: 14, color: noiseColor),
                    const SizedBox(width: 3),
                    Text("${db.toStringAsFixed(1)} dB", style: TextStyle(fontSize: 12, color: noiseColor)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(data['location'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
