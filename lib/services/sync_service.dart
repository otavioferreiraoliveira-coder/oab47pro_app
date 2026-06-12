import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/estado.dart';

const _localKey = 'oab47_estado';
const _tableName = 'progresso';

class SyncService {
  static final _db = Supabase.instance.client;

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
    final user = _db.auth.currentUser;
    if (user == null) return false;
    try {
      // Fetch remote
      final rows = await _db
          .from(_tableName)
          .select('dados')
          .eq('user_id', user.id)
          .limit(1);

      if (rows.isNotEmpty && rows.first['dados'] != null) {
        final remote = EstadoApp.fromJson(
            Map<String, dynamic>.from(rows.first['dados'] as Map));
        estado.mergeFrom(remote);
      }

      // Upsert local → remote
      await _db.from(_tableName).upsert({
        'user_id': user.id,
        'dados': estado.toJson(),
        'atualizado_em': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      await saveLocal(estado);
      return true;
    } catch (e) {
      return false;
    }
  }
}
