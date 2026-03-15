import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 引入读取保险箱的库

class AIService {

  static Future<String?> analyzeFood(File imageFile) async {
    // 安全做法：从 .env 文件中动态读取 Key
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("Error: API Key is missing in .env file");
      return null;
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final imageBytes = await imageFile.readAsBytes();

      final prompt = TextPart('''
        Analyze this image. If it contains food, identify it and estimate its nutritional value per serving.
        You MUST respond ONLY with a valid JSON format exactly like this example, without any markdown formatting like ```json:
        {
          "food_name": "Steak and Eggs",
          "calories": 828,
          "protein": 88.8,
          "carbs": 58.2,
          "fat": 26.0,
          "health_score": 8
        }
      ''');

      final imageParts = [DataPart('image/jpeg', imageBytes)];

      final response = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);

      return response.text;
    } catch (e) {
      debugPrint("AI Analysis Error: $e");
      return null;
    }
  }
}