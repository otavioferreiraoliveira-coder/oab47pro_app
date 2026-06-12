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
    final data = jsonDecode(resp.body);
    if (data is! Map) throw Exception('Resposta inesperada do Gemini');
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) throw Exception('Sem resposta do Gemini');
    final first = candidates.first;
    if (first is! Map) throw Exception('Candidato inválido');
    final content = first['content'];
    if (content is! Map) throw Exception('Sem conteúdo');
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) throw Exception('Sem partes');
    final text = parts
        .where((p) => p is Map && p['thought'] != true)
        .map((p) => (p is Map && p['text'] is String) ? p['text'] as String : '')
        .join('')
        .trim();
    if (text.isEmpty) throw Exception('Resposta vazia do Gemini');
    return text;
  }
}
