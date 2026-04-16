import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/timeline_event.dart';
import 'auth_service.dart';

class TimelineEventService {
  static const String _storagePrefix = 'timeline_events_v1';

  Future<List<TimelineEvent>> loadEvents({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _buildKey(userId);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(TimelineEvent.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEvents(List<TimelineEvent> events, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _buildKey(userId);
    final payload = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(key, payload);
  }

  Future<void> upsertEvent(TimelineEvent event, {String? userId}) async {
    final events = await loadEvents(userId: userId);
    final idx = events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      events[idx] = event;
    } else {
      events.add(event);
    }
    await saveEvents(events, userId: userId);
  }

  Future<void> deleteEvent(String eventId, {String? userId}) async {
    final events = await loadEvents(userId: userId);
    events.removeWhere((e) => e.id == eventId);
    await saveEvents(events, userId: userId);
  }

  String _buildKey(String? userId) {
    final fallbackUserId = AuthService().currentUser?.id;
    final id = (userId ?? fallbackUserId ?? 'anonymous').trim();
    return '${_storagePrefix}_$id';
  }
}

