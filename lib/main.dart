import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'service/database_service.dart';
import 'providers/sensor_provider.dart';
import 'service/ai_service.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';

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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
          }
          if (snapshot.hasData) {
            return const MainNavigationScreen();
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result != null) {
        try {
          String cleanJson = result.replaceAll('```json', '').replaceAll('```', '').trim();
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis format error, please try again. ❌")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis Failed. Check API Key or Network ❌")));
      }
    }
  }

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
          SettingsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (BuildContext ctx) {
              return SafeArea(
                child: Wrap(
                  children:[
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
          children:[
            IconButton(icon: Icon(Icons.calendar_today, color: _selectedIndex == 0 ? Colors.green : Colors.grey), onPressed: () => setState(() => _selectedIndex = 0)),
            IconButton(icon: Icon(Icons.map_outlined, color: _selectedIndex == 1 ? Colors.green : Colors.grey), onPressed: () => setState(() => _selectedIndex = 1)),
            const SizedBox(width: 40),
            IconButton(icon: Icon(Icons.people_outline, color: _selectedIndex == 2 ? Colors.green : Colors.grey), onPressed: () => setState(() => _selectedIndex = 2)),
            IconButton(icon: Icon(Icons.settings_outlined, color: _selectedIndex == 3 ? Colors.green : Colors.grey), onPressed: () => setState(() => _selectedIndex = 3)),
          ],
        ),
      ),
    );
  }

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
          _bottomSheetNutrientBar("Protein", (foodData['protein'] / 100).clamp(0.0, 1.0), Colors.green, "${foodData['protein']}g"),
          _bottomSheetNutrientBar("Carbs", (foodData['carbs'] / 100).clamp(0.0, 1.0), Colors.orange, "${foodData['carbs']}g"),
          _bottomSheetNutrientBar("Fat", (foodData['fat'] / 100).clamp(0.0, 1.0), Colors.yellow.shade700, "${foodData['fat']}g"),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () async {
                Navigator.pop(context);
                final sensorProvider = context.read<SensorProvider>();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Saving meal to cloud... ☁️")),
                );
                bool success = await DatabaseService.saveMealToCloud(
                  foodData: foodData,
                  decibel: sensorProvider.decibel,
                  location: sensorProvider.location,
                );
                if (success) {
                  sensorProvider.logMeal(foodData['calories'] as int);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Meal Logged Successfully! ✅")),
                  );
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to log meal. Please try again. ❌")),
                  );
                }
              },
              child: const Text("Log this Meal", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

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
              painter: CaloriePainter(current: sensorProvider.remainingCalories.toDouble(), total: sensorProvider.totalCaloriesTarget.toDouble()),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:[
                    Text("${sensorProvider.remainingCalories}", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF2E3E2E))),
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
