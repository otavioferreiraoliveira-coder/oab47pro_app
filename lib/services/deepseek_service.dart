import 'dart:convert';
import 'package:http/http.dart' as http;

class DeepSeekService {
  static const _url = 'https://api.deepseek.com/v1/chat/completions';

  static Future<String> generate({
    required String apiKey,
    String model = 'deepseek-chat',
    required String prompt,
    String? systemPrompt,
    double temperature = 0.25,
    int maxTokens = 1600,
  }) async {
    if (apiKey.isEmpty) throw Exception('Chave DeepSeek não configurada');
    final messages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final resp = await http.post(
      Uri.parse(_url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw Exception('Chave DeepSeek inválida');
    }
    if (resp.statusCode == 429) {
      throw Exception('Limite DeepSeek atingido — aguarde 1 minuto');
    }
    if (resp.statusCode != 200) {
      throw Exception('DeepSeek erro ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = (data['choices'] as List?)?.first['message']['content'] as String? ?? '';
    if (content.isEmpty) throw Exception('DeepSeek: resposta vazia');
    return content;
  }
}
