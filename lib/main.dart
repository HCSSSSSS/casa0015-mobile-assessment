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
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

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
            // Re-fetch user preferences after login
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.read<SensorProvider>().refreshOnAuthChange();
              }
            });
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text("Analyzing your food...",
                    style: TextStyle(fontSize: 15, decoration: TextDecoration.none, color: Colors.black87)),
                SizedBox(height: 4),
                Text("Powered by Gemini AI ✨",
                    style: TextStyle(fontSize: 12, decoration: TextDecoration.none, color: Colors.grey)),
              ],
            ),
          ),
        ),
      );

      File imageFile = File(photo.path);
      final result = await AIService.analyzeFood(imageFile);

      if (!mounted) return;
      Navigator.of(context).pop();

      if (result != null) {
        try {
          String cleanJson = result.replaceAll('```json', '').replaceAll('```', '').trim();
          final foodData = jsonDecode(cleanJson);

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _buildResultBottomSheet(context, foodData),
          );
        } catch (e) {
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

  Future<void> _showDescribeDialog() async {
    final TextEditingController descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Describe Your Food", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: descController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "e.g. A bowl of tomato beef noodles with 2 meatballs...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final desc = descController.text.trim();
              if (desc.isEmpty) return;
              Navigator.pop(context);
              await _processDescription(desc);
            },
            child: const Text("Analyze", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processDescription(String description) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text("Analyzing your food...",
                  style: TextStyle(fontSize: 15, decoration: TextDecoration.none, color: Colors.black87)),
              SizedBox(height: 4),
              Text("Powered by Gemini AI ✨",
                  style: TextStyle(fontSize: 12, decoration: TextDecoration.none, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );

    final result = await AIService.analyzeFoodByText(description);

    if (!mounted) return;
    Navigator.of(context).pop();

    if (result != null) {
      try {
        String cleanJson = result.replaceAll('```json', '').replaceAll('```', '').trim();
        final foodData = jsonDecode(cleanJson);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildResultBottomSheet(context, foodData),
        );
      } catch (e) {
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
                    ListTile(
                      leading: const Icon(Icons.edit_note, color: Colors.purple),
                      title: const Text('Describe Food'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showDescribeDialog();
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
              icon: Icon(Icons.history, color: _selectedIndex == 2 ? Colors.green : Colors.grey),
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
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(foodData['food_name'] ?? "Unknown Food",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E3E2E))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                child: Text("Score: ${foodData['health_score']}/10",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutrientInfo("Calories", "${foodData['calories']}", "Kcal", Colors.orange),
              _buildNutrientInfo("Protein", "${foodData['protein']}g", "Daily", Colors.blue),
              _buildNutrientInfo("Carbs", "${foodData['carbs']}g", "Daily", Colors.green),
            ],
          ),
          const SizedBox(height: 25),
          const Text("Nutritional Breakdown", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _bottomSheetNutrientBar("Protein", (foodData['protein'] / 50).toDouble().clamp(0, 1), Colors.blue, "${foodData['protein']}g"),
          _bottomSheetNutrientBar("Carbs", (foodData['carbs'] / 200).toDouble().clamp(0, 1), Colors.green, "${foodData['carbs']}g"),
          _bottomSheetNutrientBar("Fat", (foodData['fat'] / 70).toDouble().clamp(0, 1), Colors.orange, "${foodData['fat']}g"),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => _handleLogMeal(context, foodData),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("Log This Meal", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientInfo(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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
                Flexible(
                    child: _sensorCard(context, "Ambient Noise",
                        "${sensorProvider.decibel.toStringAsFixed(1)} dB", Icons.graphic_eq, Colors.orange)),
                const SizedBox(width: 12),
                Flexible(
                    child: _sensorCard(context, "Spatial Context", sensorProvider.location, Icons.location_on,
                        Colors.blue)),
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
                  Flexible(
                    child: Text(_getNoiseAdvice(sensorProvider.decibel),
                        style: TextStyle(fontSize: 13, color: _getNoiseColor(sensorProvider.decibel))),
                  ),
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
    if (db < 60) return "Calm environment – great time to eat mindfully.";
    if (db < 80) return "Moderate noise – stay aware of your eating pace.";
    return "Noisy environment – try to eat slowly and avoid overeating.";
  }

  Color _getNoiseColor(double db) {
    if (db < 60) return Colors.green;
    if (db < 80) return Colors.orange;
    return Colors.red;
  }

  IconData _getNoiseIcon(double db) {
    if (db < 60) return Icons.spa_outlined;
    if (db < 80) return Icons.volume_down;
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
