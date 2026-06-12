import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static Future<String> generate({
    required String apiKey,
    required String model,
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    return generateWithSystem(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  static Future<String> generateWithSystem({
    required String apiKey,
    required String model,
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    if (apiKey.isEmpty) throw Exception('Chave Gemini não configurada');
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
    final body = <String, dynamic>{
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [{'text': systemPrompt}]
      };
    }
    if (model.startsWith('gemini-2.5')) {
      (body['generationConfig'] as Map)['thinkingConfig'] = {'thinkingBudget': 0};
    }
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw Exception('Erro Gemini: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) throw Exception('Sem resposta');
    final content = candidates.first['content'] as Map?;
    final parts = (content?['parts'] as List?)
        ?.where((p) => (p as Map)['thought'] != true)
        .toList();
    if (parts == null || parts.isEmpty) throw Exception('Sem conteúdo');
    return parts.map((p) => (p as Map)['text'] as String? ?? '').join('').trim();
  }
}
