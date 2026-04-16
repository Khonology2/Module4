// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/app_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  bool _notifications = true;
  bool _autoSync = true;
  String _language = 'English';
  String _syncFrequency = 'Hourly';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      _darkMode = await SettingsService.getDarkMode();
      _notifications = await SettingsService.getNotifications();
      _autoSync = await SettingsService.getAutoSync();
      _language = await SettingsService.getLanguage();
      _syncFrequency = await SettingsService.getSyncFrequency();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Appearance',
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: _darkMode,
                  onChanged: (value) async {
                    await SettingsService.saveDarkMode(value);
                    setState(() => _darkMode = value);
                  },
                ),
                ListTile(
                  title: const Text('Language'),
                  subtitle: Text(_language),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguageDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Notifications',
              children: [
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  value: _notifications,
                  onChanged: (value) async {
                    await SettingsService.saveNotifications(value);
                    setState(() => _notifications = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Data & Sync',
              children: [
                SwitchListTile(
                  title: const Text('Auto Sync'),
                  value: _autoSync,
                  onChanged: (value) async {
                    await SettingsService.saveAutoSync(value);
                    setState(() => _autoSync = value);
                  },
                ),
                ListTile(
                  title: const Text('Sync Frequency'),
                  subtitle: Text(_syncFrequency),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSyncFrequencyDialog(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSyncFrequencyDialog() async {
    final frequencies = [
      'Hourly',
      'Every 6 Hours',
      'Daily',
      'Weekly',
      'Manual'
    ];
    String? selected = _syncFrequency;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: FlownetColors.graphiteGray,
          title: const Text('Select Sync Frequency',
              style: TextStyle(color: FlownetColors.pureWhite)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: frequencies.map((freq) {
              return ListTile(
                title: Text(freq,
                    style: const TextStyle(color: FlownetColors.pureWhite)),
                leading: Icon(
                  selected == freq
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected == freq
                      ? FlownetColors.electricBlue
                      : FlownetColors.coolGray,
                ),
                onTap: () {
                  setState(() => selected = freq);
                  Navigator.pop(context, freq);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (result != null) {
      await SettingsService.saveSyncFrequency(result);
      setState(() => _syncFrequency = result);
    }
  }

  Future<void> _showLanguageDialog() async {
    final languages = ['English', 'Spanish', 'French', 'German', 'Portuguese'];
    String? selected = _language;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: FlownetColors.graphiteGray,
          title: const Text('Select Language',
              style: TextStyle(color: FlownetColors.pureWhite)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) {
              return ListTile(
                title: Text(lang,
                    style: const TextStyle(color: FlownetColors.pureWhite)),
                leading: Icon(
                  selected == lang
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected == lang
                      ? FlownetColors.electricBlue
                      : FlownetColors.coolGray,
                ),
                onTap: () {
                  setState(() => selected = lang);
                  Navigator.pop(context, lang);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (result != null) {
      await SettingsService.saveLanguage(result);
      setState(() => _language = result);
    }
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: FlownetColors.coolGray,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: FlownetColors.graphiteGray,
          child: Column(children: children),
        ),
      ],
    );
  }
}
