import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _darkModeKey = 'dark_mode';
  static const String _notificationsKey = 'notifications';
  static const String _languageKey = 'language';
  static const String _autoSyncKey = 'auto_sync';
  static const String _syncFrequencyKey = 'sync_frequency';
  static const String _analyticsKey = 'analytics';
  static const String _notificationPrefsKey = 'notification_prefs';
  // New keys for updated data sync settings
  static const String _syncOnMobileDataKey = 'sync_on_mobile_data';
  static const String _autoBackupKey = 'auto_backup';

  // Default values
  static const bool _defaultDarkMode = false;
  static const bool _defaultNotifications = true;
  static const String _defaultLanguage = 'English';
  static const bool _defaultAutoSync = true;
  static const String _defaultSyncFrequency = 'Hourly';
  static const bool _defaultAnalytics = true;
  static const bool _defaultNotificationPrefs = true;
  // New default values for updated data sync settings
  static const bool _defaultSyncOnMobileData = false;
  static const bool _defaultAutoBackup = false;

  // Get settings
  static Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? _defaultDarkMode;
  }

  static Future<bool> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? _defaultNotifications;
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? _defaultLanguage;
  }

  static Future<bool> getAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? _defaultAutoSync;
  }

  static Future<String> getSyncFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncFrequencyKey) ?? _defaultSyncFrequency;
  }

  // New getters for updated data sync settings
  static Future<bool> getSyncOnMobileData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncOnMobileDataKey) ?? _defaultSyncOnMobileData;
  }

  static Future<bool> getAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupKey) ?? _defaultAutoBackup;
  }

  static Future<bool> getAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_analyticsKey) ?? _defaultAnalytics;
  }

  static Future<bool> getNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPrefsKey) ?? _defaultNotificationPrefs;
  }

  // Save settings
  static Future<void> saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  static Future<void> saveNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  static Future<void> saveLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
  }

  static Future<void> saveAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, value);
  }

  static Future<void> saveSyncFrequency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncFrequencyKey, value);
  }

  // New savers for updated data sync settings
  static Future<void> saveSyncOnMobileData(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncOnMobileDataKey, value);
  }

  static Future<void> saveAutoBackup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, value);
  }

  static Future<void> saveAnalytics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsKey, value);
  }

  static Future<void> saveNotificationPrefs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPrefsKey, value);
  }
}