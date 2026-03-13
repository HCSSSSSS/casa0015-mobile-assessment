import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'providers/sensor_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 注意：在实际设备运行前，你需要完成 Firebase 控制台配置并下载 google-services.json
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  
  runApp(
    MultiProvider(
      providers: [
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
        children: [
          const DashboardScreen(),
          const Center(child: Text("Connected Map")),
          const Center(child: Text("Forum")),
          const Center(child: Text("Settings")),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 这里将来集成 Gemini AI 识图逻辑
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("AI Vision Coming Soon!")),
          );
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
          children: [
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
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 Provider 获取传感器数据
    final sensorProvider = context.watch<SensorProvider>();

    return SingleChildScrollView(
      child: Column(
        children: [
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
                  children: [
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
              children: [
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
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
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
        children: [
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
        colors: [Colors.greenAccent, Colors.green, Colors.greenAccent],
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
