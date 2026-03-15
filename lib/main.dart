import 'dart:io';
import 'dart:convert'; // 用于解析 AI 返回的 JSON 数据
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 引入环境变量保险箱

import 'providers/sensor_provider.dart';
import 'service/ai_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 加载安全环境变量 (.env)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("环境变量加载失败，请检查是否创建了 .env 文件: $e");
  }

  // 2. 初始化 Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  runApp(
    MultiProvider(
      providers:[
        ChangeNotifierProvider(create: (_) => SensorProvider()),
      ],
      child: const SenseFoodApp(),
    ),
  );
}

class SenseFoodApp extends StatelessWidget {
  const SenseFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SenseFood',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      body: IndexedStack(
        index: _selectedIndex,
        children: const[
          DashboardScreen(),
          Center(child: Text("Connected Map")),
          Center(child: Text("Forum")),
          Center(child: Text("Settings")),
        ],
      ),
      // 核心交互：AI 拍照与炫酷结果弹窗
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ImagePicker picker = ImagePicker();
          final XFile? photo = await picker.pickImage(source: ImageSource.camera);

          if (photo != null) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("AI is analyzing your food... ⏳"),
                duration: Duration(seconds: 3),
              ),
            );

            File imageFile = File(photo.path);
            final result = await AIService.analyzeFood(imageFile);

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar(); // 隐藏加载提示

            if (result != null) {
              try {
                // 清洗并解析 JSON
                String cleanJson = result.replaceAll('```json', '').replaceAll('```', '').trim();
                final foodData = jsonDecode(cleanJson);

                // 冲刺高分交互：从底部弹出一个精美的识别结果卡片
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return _buildResultBottomSheet(context, foodData);
                  },
                );
              } catch (e) {
                debugPrint("JSON Parse Error: $e\nRaw data: $result");
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis format error, please try again. ❌")));
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis Failed. Check API Key or Network ❌")));
            }
          }
        },
        backgroundColor: Colors.green,
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 70,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children:[
            IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => setState(() => _selectedIndex = 0)),
            IconButton(icon: const Icon(Icons.map_outlined), onPressed: () => setState(() => _selectedIndex = 1)),
            const SizedBox(width: 40),
            IconButton(icon: const Icon(Icons.people_outline), onPressed: () => setState(() => _selectedIndex = 2)),
            IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => setState(() => _selectedIndex = 3)),
          ],
        ),
      ),
    );
  }

  // 炫酷的底部营养卡片 UI (完美复刻你截图的风格)
  Widget _buildResultBottomSheet(BuildContext context, Map<String, dynamic> foodData) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Center(
            child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              Text("AI Vision Result", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(Icons.verified, color: Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          Text("${foodData['food_name']}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          // 核心热量展示
          Row(
            children:[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Text("${foodData['calories']}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
              ),
              const SizedBox(width: 20),
              const Text("Kcal\nEstimated", style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 30),
          // 营养素横条展示
          _bottomSheetNutrientBar("Protein", (foodData['protein'] / 100).clamp(0.0, 1.0), Colors.green, "${foodData['protein']}g"),
          _bottomSheetNutrientBar("Carbs", (foodData['carbs'] / 100).clamp(0.0, 1.0), Colors.orange, "${foodData['carbs']}g"),
          _bottomSheetNutrientBar("Fat", (foodData['fat'] / 100).clamp(0.0, 1.0), Colors.yellow.shade700, "${foodData['fat']}g"),
          const Spacer(),
          // 确认保存按钮
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meal Logged Successfully!")));
              },
              child: const Text("Log this Meal", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 弹窗专用的精美营养条
  Widget _bottomSheetNutrientBar(String label, double percent, Color color, String valueStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children:[
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Expanded(
            child: LinearProgressIndicator(value: percent, backgroundColor: Colors.grey.shade200, color: color, minHeight: 8, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 15),
          SizedBox(width: 50, child: Text(valueStr, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// ---------------- 以下为仪表盘与绘图组件 (保持不变) ----------------

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sensorProvider = context.watch<SensorProvider>();

    return SingleChildScrollView(
      child: Column(
        children:[
          const SizedBox(height: 60),
          TableCalendar(
            focusedDay: DateTime.now(),
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            calendarFormat: CalendarFormat.week,
            headerVisible: false,
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.green.withAlpha(50), shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 240,
            width: 240,
            child: CustomPaint(
              painter: CaloriePainter(current: 828, total: 2000),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:[
                    const Text("828", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF2E3E2E))),
                    Text("Kcal Left", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:[
                _sensorCard(context, "Ambient Noise", "${sensorProvider.decibel.toStringAsFixed(1)} dB", Icons.graphic_eq, Colors.orange),
                _sensorCard(context, "Spatial Context", sensorProvider.location, Icons.location_on, Colors.blue),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _nutrientBar("Protein", 0.7, Colors.green),
          _nutrientBar("Carbs", 0.4, Colors.orange),
          _nutrientBar("Fat", 0.3, Colors.yellow.shade700),
        ],
      ),
    );
  }

  Widget _sensorCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.43,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow:[BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children:[
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _nutrientBar(String label, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: percent, backgroundColor: Colors.grey.shade200, color: color, minHeight: 8, borderRadius: BorderRadius.circular(10)),
        ],
      ),
    );
  }
}

class CaloriePainter extends CustomPainter {
  final double current;
  final double total;
  CaloriePainter({required this.current, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()..color = Colors.grey.shade100..style = PaintingStyle.stroke..strokeWidth = 16;
    canvas.drawCircle(center, radius, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors:[Colors.greenAccent, Colors.green, Colors.greenAccent],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    double sweepAngle = (current / total) * 2 * math.pi;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(CaloriePainter oldDelegate) => true;
}