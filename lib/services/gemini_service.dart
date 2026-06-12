import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static Future<String> generate({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    if (apiKey.isEmpty) throw Exception('Chave Gemini não configurada');
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Erro Gemini: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) throw Exception('Sem resposta');
    final content = candidates.first['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) throw Exception('Sem conteúdo');
    return parts.first['text'] as String? ?? '';
  }
}
