import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // 1. 文本类型的弹窗 (给 Name 用)
  Future<void> _editText(BuildContext context, String field, String currentVal, String title) async {
    final TextEditingController controller = TextEditingController(text: currentVal == "Not set" ? "" : currentVal);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Edit $title"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter new $title", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({field: controller.text.trim()}, SetOptions(merge: true));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 2. 核心交互：3D 滚轮选择器
  Future<void> _showPicker(BuildContext context, String field, String title, List<String> options, int initialIndex) async {
    int selectedIndex = initialIndex < 0 ? 0 : initialIndex;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          height: 300,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              // 顶部的取消和完成按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16))),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        dynamic valueToSave = options[selectedIndex];

                        // 清洗数据：把 "60 kg" 提取出数字 60；对于纯数字的 age，直接转 int
                        if (field == 'weight' || field == 'target_calories') {
                          valueToSave = int.tryParse(valueToSave.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        } else if (field == 'age') {
                          valueToSave = int.tryParse(valueToSave.toString()) ?? 0;
                        }

                        // 存入云端
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({field: valueToSave}, SetOptions(merge: true));

                        // 联动主页圆环
                        if (field == 'target_calories' && context.mounted) {
                          context.read<SensorProvider>().updateTargetCalories((valueToSave as num).toInt());
                        }
                      },
                      child: const Text("Done", style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 滚轮组件
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(initialItem: initialIndex),
                  onSelectedItemChanged: (int index) => selectedIndex = index,
                  children: options.map((String value) => Center(child: Text(value, style: const TextStyle(fontSize: 20)))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 辅助方法：生成纯数字或带后缀的列表
  List<String> _generateList(int start, int end, {String suffix = ""}) {
    if (suffix.isEmpty) {
      return List.generate(end - start + 1, (index) => "${start + index}");
    }
    return List.generate(end - start + 1, (index) => "${start + index} $suffix");
  }

  // 3. 系统开关控制
  Future<void> _toggleSystemSetting(String field, bool currentVal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({field: !currentVal}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(title: const Text("Settings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // 准备滚轮的数据（去掉了 Age 的后缀）
          final genderOptions = ["Male", "Female", "Other"];
          final ageOptions = _generateList(10, 100);
          final weightOptions = _generateList(30, 200, suffix: "kg");
          final calorieOptions = List.generate(61, (index) => "${1000 + (index * 50)} Kcal");

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildSectionHeader("Account"),
              _buildSettingCard([
                _buildSettingRow(context, Icons.person, Colors.blue, "Display Name", data['name']?.toString() ?? "Not set", () => _editText(context, 'name', data['name']?.toString() ?? "", "Display Name")),
                _buildSettingRow(context, Icons.wc, Colors.pinkAccent, "Gender", data['gender']?.toString() ?? "Not set", () => _showPicker(context, 'gender', "Select Gender", genderOptions, genderOptions.indexOf(data['gender'] ?? "Male"))),
                // Age 现在只显示纯数字
                _buildSettingRow(context, Icons.cake, Colors.yellow.shade700, "Age", "${data['age'] ?? '-'}", () => _showPicker(context, 'age', "Select Age", ageOptions, ageOptions.indexOf("${data['age'] ?? '25'}"))),
              ]),

              const SizedBox(height: 20),
              _buildSectionHeader("Body & Goals"),
              _buildSettingCard([
                _buildSettingRow(context, Icons.monitor_weight, Colors.teal, "Weight", "${data['weight'] ?? '-'} kg", () => _showPicker(context, 'weight', "Select Weight", weightOptions, weightOptions.indexOf("${data['weight'] ?? '60'} kg"))),
                _buildSettingRow(context, Icons.local_fire_department, Colors.orange, "Daily Goal", "${data['target_calories'] ?? '2000'} Kcal", () => _showPicker(context, 'target_calories', "Daily Goal", calorieOptions, calorieOptions.indexOf("${data['target_calories'] ?? '2000'} Kcal"))),
              ]),

              const SizedBox(height: 20),
              _buildSectionHeader("System"),
              _buildSettingCard([
                _buildToggleRow(Icons.graphic_eq, Colors.purple, "Ambient Sensing", data['enable_noise'] ?? true, () => _toggleSystemSetting('enable_noise', data['enable_noise'] ?? true)),
                _buildToggleRow(Icons.location_on, Colors.blueAccent, "Location Tagging", data['enable_location'] ?? true, () => _toggleSystemSetting('enable_location', data['enable_location'] ?? true)),
              ]),

              const SizedBox(height: 40),
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.red.shade100))),
                  icon: const Icon(Icons.logout),
                  label: const Text("Sign Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(left: 8, bottom: 10), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)));
  }

  Widget _buildSettingCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: rows),
    );
  }

  Widget _buildSettingRow(BuildContext context, IconData icon, Color iconColor, String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withAlpha(30), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 15),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Text(value, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(IconData icon, Color iconColor, String title, bool isActive, VoidCallback onToggle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withAlpha(30), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 15),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const Spacer(),
          Switch(
            value: isActive,
            activeThumbColor: Colors.green,
            onChanged: (val) => onToggle(),
          ),
        ],
      ),
    );
  }
}