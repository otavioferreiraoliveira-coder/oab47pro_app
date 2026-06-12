import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../models/estado.dart';

const _localKey = 'oab47_estado';
const _uidKey = 'oab47-uid';
const _tableName = 'progresso';

class SyncService {
  // ID fixo compartilhado — mesmo ID em web e Flutter (app pessoal)
  // Web usa localStorage["oab47-uid"] ou "oab47pro_user_main" como fallback
  static Future<String> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_uidKey);
    if (stored != null && stored.isNotEmpty) return stored;
    return 'oab47pro_user_main';
  }

  static Future<void> setUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, uid);
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
