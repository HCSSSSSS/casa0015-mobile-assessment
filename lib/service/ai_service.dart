import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class AIService {
  // 注意：这个 API Key 在生产环境下应当通过环境变量或安全存储获取
  static const String _apiKey = 'AIzaSyDl4jm53lXeJ6Ok1v1P4yzlxpbNPPyqH14';

  static Future<String?> analyzeFood(File imageFile) async {
    if (_apiKey.isEmpty || _apiKey.startsWith('YOUR')) {
      debugPrint("Error: 请先在 AIService 中填入有效的 Gemini API Key");
      return null;
    }

    try {

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

      final imageBytes = await imageFile.readAsBytes();

      final prompt = TextPart('''
        Analyze this image. If it contains food, identify it and estimate its nutritional value per serving.
        You MUST respond ONLY with a valid JSON format exactly like this example, without any markdown formatting:
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
