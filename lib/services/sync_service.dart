import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../models/estado.dart';

const _localKey = 'oab47_estado';
const _uidKey = 'oab47-uid';
const _tableName = 'progresso';

class SyncService {
  // Gera ou carrega UUID estável do dispositivo (idêntico ao web)
  static Future<String> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    var uid = prefs.getString(_uidKey);
    if (uid == null || uid.isEmpty) {
      uid = _gerarUuid();
      await prefs.setString(_uidKey, uid);
    }
    return uid;
  }

  static Future<void> setUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, uid);
  }

  static String _gerarUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
        '-${hex(bytes[4])}${hex(bytes[5])}'
        '-${hex(bytes[6])}${hex(bytes[7])}'
        '-${hex(bytes[8])}${hex(bytes[9])}'
        '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  static Future<EstadoApp> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null) return EstadoApp();
    try {
      return EstadoApp.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return EstadoApp();
    }
  }

  static Future<void> saveLocal(EstadoApp estado) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, jsonEncode(estado.toJson()));
  }

  static Future<bool> syncToSupabase(EstadoApp estado) async {
    try {
      final uid = await getUid();
      final headers = {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      };
      // Lê remoto
      final res = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/$_tableName?user_id=eq.$uid&select=dados'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final rows = jsonDecode(res.body) as List<dynamic>;
        if (rows.isNotEmpty && rows.first['dados'] != null) {
          final remote = EstadoApp.fromJson(
              Map<String, dynamic>.from(rows.first['dados'] as Map));
          estado.mergeFrom(remote);
        }
      }
      // Upsert local → remoto
      await http.post(
        Uri.parse('$supabaseUrl/rest/v1/$_tableName'),
        headers: headers,
        body: jsonEncode({
          'user_id': uid,
          'dados': estado.toJson(),
          'atualizado_em': DateTime.now().toIso8601String(),
        }),
      );
      await saveLocal(estado);
      return true;
    } catch (_) {
      return false;
    }
  }
}
