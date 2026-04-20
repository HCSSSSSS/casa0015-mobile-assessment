import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/sensor_provider.dart';
import 'service/ai_service.dart';
import 'service/database_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/map_screen.dart';
import 'screens/journal_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("环境变量加载失败，请检查是否创建了 .env 文件: $e");
  }

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SensorProvider())],
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            );
          }
          if (snapshot.hasData) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(snapshot.data!.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
                }
                final data = userSnapshot.data?.data() as Map<String, dynamic>?;
                if (data == null || data['profile_completed'] != true) {
                  return const OnboardingScreen();
                }
                return const MainNavigationScreen();
              },
            );
          }
          return const LoginScreen();
        },
      ),
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

  Future<void> _processImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: source);

    if (photo != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("AI is analyzing your food... ⏳"),
          duration: Duration(seconds: 3),
        ),
      );

      File imageFile = File(photo.path);
      final result = await AIService.analyzeFood(imageFile);

      // 安全检查 1: AI 分析之后
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result != null) {
        try {
          String cleanJson = result
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();
          final foodData = jsonDecode(cleanJson);

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Analysis format error, please try again. ❌")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Analysis Failed. Check API Key or Network ❌")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          DashboardScreen(),
          MapScreen(),
          JournalScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (BuildContext ctx) {
              return SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.camera_alt, color: Colors.green),
                      title: const Text('Take a Photo'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _processImage(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library, color: Colors.blue),
                      title: const Text('Choose from Gallery'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _processImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              );
            },
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
            IconButton(
              icon: Icon(Icons.calendar_today, color: _selectedIndex == 0 ? Colors.green : Colors.grey),
              onPressed: () => setState(() => _selectedIndex = 0),
            ),
            IconButton(
              icon: Icon(Icons.map_outlined, color: _selectedIndex == 1 ? Colors.green : Colors.grey),
              onPressed: () => setState(() => _selectedIndex = 1),
            ),
            const SizedBox(width: 40),
            IconButton(
              icon: Icon(Icons.book_outlined, color: _selectedIndex == 2 ? Colors.green : Colors.grey),
              onPressed: () => setState(() => _selectedIndex = 2),
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, color: _selectedIndex == 3 ? Colors.green : Colors.grey),
              onPressed: () => setState(() => _selectedIndex = 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBottomSheet(BuildContext context, Map<String, dynamic> foodData) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("AI Vision Result", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(Icons.verified, color: Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "${foodData['food_name']}",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
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
          _bottomSheetNutrientBar("Protein", (foodData['protein'] / 100).toDouble().clamp(0.0, 1.0), Colors.green, "${foodData['protein']}g"),
          _bottomSheetNutrientBar("Carbs", (foodData['carbs'] / 100).toDouble().clamp(0.0, 1.0), Colors.orange, "${foodData['carbs']}g"),
          _bottomSheetNutrientBar("Fat", (foodData['fat'] / 100).toDouble().clamp(0.0, 1.0), Colors.yellow.shade700, "${foodData['fat']}g"),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () async => _handleLogMeal(context, foodData),
              child: const Text("Log This Meal", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogMeal(BuildContext context, Map<String, dynamic> foodData) async {
    Navigator.pop(context);
    final sensorProvider = context.read<SensorProvider>();
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(const SnackBar(content: Text("Saving meal to cloud... ☁️")));

    bool success = await DatabaseService.saveMealToCloud(
      foodData: foodData,
      decibel: sensorProvider.decibel,
      location: sensorProvider.location,
    );

    if (!mounted) return;

    if (success) {
      sensorProvider.refreshDataForDate(DateTime.now());
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text("Meal Logged Successfully! ✅")));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text("Failed to log meal. Please try again. ❌")));
    }
  }

  Widget _bottomSheetNutrientBar(String label, double percent, Color color, String valueStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _isMonthView = false;
  Map<String, int> _monthlyCalories = {};

  @override
  void initState() {
    super.initState();
    _loadMonthData(_focusedDay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SensorProvider>().refreshDataForDate(_selectedDay);
      }
    });
  }

  Future<void> _loadMonthData(DateTime month) async {
    final data = await DatabaseService.getMonthlyCalories(month.year, month.month);
    if (mounted) {
      setState(() => _monthlyCalories = data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensorProvider = context.watch<SensorProvider>();

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isMonthView = !_isMonthView);
                    if (_isMonthView) _loadMonthData(_focusedDay);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(_isMonthView ? Icons.view_week : Icons.calendar_month, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(_isMonthView ? "Week" : "Month", style: const TextStyle(fontSize: 13, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            calendarFormat: _isMonthView ? CalendarFormat.month : CalendarFormat.week,
            headerVisible: _isMonthView,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.week: 'Week',
            },
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            availableGestures: AvailableGestures.all,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              context.read<SensorProvider>().refreshDataForDate(selectedDay);
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              if (_isMonthView) _loadMonthData(focusedDay);
            },
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Color(0x334CAF50), shape: BoxShape.circle),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                if (!_isMonthView) return null;
                final key = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
                final calories = _monthlyCalories[key] ?? 0;
                final intensity = (calories / 2000).clamp(0.0, 1.0);
                if (calories == 0) return null;
                return Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withValues(alpha: 0.1 + intensity * 0.6),
                    ),
                    child: Center(
                      child: Text("${day.day}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: intensity > 0.5 ? Colors.white : Colors.black87,
                          )),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!isSameDay(_selectedDay, DateTime.now()))
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDay = DateTime.now();
                  _focusedDay = DateTime.now();
                });
                context.read<SensorProvider>().refreshDataForDate(DateTime.now());
              },
              icon: const Icon(Icons.today, color: Colors.green, size: 16),
              label: const Text("Back to Today", style: TextStyle(color: Colors.green)),
            ),
          const SizedBox(height: 30),
          SizedBox(
            height: 240,
            width: 240,
            child: CustomPaint(
              painter: CaloriePainter(
                current: sensorProvider.remainingCalories.toDouble(),
                total: sensorProvider.totalCaloriesTarget.toDouble(),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${sensorProvider.remainingCalories}",
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF2E3E2E)),
                    ),
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _getNoiseColor(sensorProvider.decibel).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(_getNoiseIcon(sensorProvider.decibel),
                      color: _getNoiseColor(sensorProvider.decibel), size: 18),
                  const SizedBox(width: 8),
                  Text(_getNoiseAdvice(sensorProvider.decibel),
                      style: TextStyle(fontSize: 13, color: _getNoiseColor(sensorProvider.decibel))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _nutrientBar("Protein", (sensorProvider.protein / 150).clamp(0.0, 1.0), Colors.green, "${sensorProvider.protein.toStringAsFixed(1)}g / 150g"),
          _nutrientBar("Carbs", (sensorProvider.carbs / 250).clamp(0.0, 1.0), Colors.orange, "${sensorProvider.carbs.toStringAsFixed(1)}g / 250g"),
          _nutrientBar("Fat", (sensorProvider.fat / 65).clamp(0.0, 1.0), Colors.yellow.shade700, "${sensorProvider.fat.toStringAsFixed(1)}g / 65g"),
        ],
      ),
    );
  }

  String _getNoiseAdvice(double db) {
    if (db < 50) return "Quiet environment – great time to eat mindfully.";
    if (db < 70) return "Moderate noise – stay aware of your eating pace.";
    return "Noisy environment – try to eat slowly and avoid overeating.";
  }

  Color _getNoiseColor(double db) {
    if (db < 50) return Colors.green;
    if (db < 70) return Colors.orange;
    return Colors.red;
  }

  IconData _getNoiseIcon(double db) {
    if (db < 50) return Icons.spa_outlined;
    if (db < 70) return Icons.volume_down;
    return Icons.volume_up;
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

  Widget _nutrientBar(String label, double percent, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
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

    final bgPaint = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
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
