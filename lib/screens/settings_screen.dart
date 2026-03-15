import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableNoiseSensing = true;
  bool _enableLocation = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children:[
          // 用户资料卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
            child: Row(
              children:[
                CircleAvatar(radius: 30, backgroundColor: Colors.green.shade100, child: const Icon(Icons.person, size: 35, color: Colors.green)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      const Text("Logged in as", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(user?.email ?? "Unknown User", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 传感器开关控制 (贴合 Connected Environment 主题)
          const Text("SENSORS & PRIVACY", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children:[
                SwitchListTile(
                  activeThumbColor: Colors.green,
                  title: const Text("Ambient Noise Sensing"),
                  subtitle: const Text("Used to evaluate dining stress"),
                  value: _enableNoiseSensing,
                  onChanged: (val) => setState(() => _enableNoiseSensing = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  activeThumbColor: Colors.green,
                  title: const Text("Location Mapping"),
                  subtitle: const Text("Tag meals to spatial context"),
                  value: _enableLocation,
                  onChanged: (val) => setState(() => _enableLocation = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // 退出登录按钮
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              icon: const Icon(Icons.logout),
              label: const Text("Sign Out", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                // 退出后监听器会自动跳回登录页
              },
            ),
          ),
        ],
      ),
    );
  }
}
