import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(title: const Text("Settings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildSectionHeader("Account"),
              _buildSettingCard([
                _buildSettingRow(Icons.person, Colors.blue, "Display Name", value: data['name'] ?? "Not set"),
                _buildSettingRow(Icons.wc, Colors.pinkAccent, "Gender", value: data['gender'] ?? "Not set"),
                _buildSettingRow(Icons.cake, Colors.yellow.shade700, "Age", value: "${data['age'] ?? '-'} years"),
              ]),

              const SizedBox(height: 20),
              _buildSectionHeader("Body & Goals"),
              _buildSettingCard([
                _buildSettingRow(Icons.monitor_weight, Colors.teal, "Weight", value: "${data['weight'] ?? '-'} kg"),
                _buildSettingRow(Icons.local_fire_department, Colors.orange, "Daily Goal", value: "${data['target_calories'] ?? '2000'} Kcal"),
              ]),

              const SizedBox(height: 20),
              _buildSectionHeader("System"),
              _buildSettingCard([
                _buildSettingRow(Icons.graphic_eq, Colors.purple, "Ambient Sensing", isToggle: true),
                _buildSettingRow(Icons.location_on, Colors.blueAccent, "Location Tagging", isToggle: true),
              ]),

              const SizedBox(height: 40),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(left: 8, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)));
  }

  Widget _buildSettingCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: rows),
    );
  }

  Widget _buildSettingRow(IconData icon, Color iconColor, String title, {String? value, bool isToggle = false}) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withAlpha(30), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: isToggle
          ? Switch(value: true, activeColor: Colors.green, onChanged: (v){})
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}