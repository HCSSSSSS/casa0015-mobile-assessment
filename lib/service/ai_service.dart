import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Library for reading .env files

class AIService {

  static Future<String?> analyzeFood(File imageFile) async {
    // Secure practice: dynamically read Key from .env file
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
      debugPrint("AI Analysis Error type: ${e.runtimeType}");
      debugPrint("AI Analysis Error: $e");
      return null;
    }
  }

  static Future<String?> analyzeFoodByText(String description) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final prompt = TextPart('''
      The user described their meal as: "$description"
      Based on this description, estimate the nutritional value.
      You MUST respond ONLY with a valid JSON format exactly like this, without any markdown formatting:
      {
        "food_name": "Tomato Beef Noodles",
        "calories": 520,
        "protein": 28.0,
        "carbs": 65.0,
        "fat": 12.0,
        "health_score": 7
      }
    ''');

      final response = await model.generateContent([Content.text(prompt.text)]);
      return response.text;
    } catch (e) {
      debugPrint("AI Text Analysis Error type: ${e.runtimeType}");
      debugPrint("AI Text Analysis Error: $e");
      return null;
    }
  }
}
