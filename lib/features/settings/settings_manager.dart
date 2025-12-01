import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings manager
class SettingsManager extends ChangeNotifier {
  static const String _sshFolderPathKey = 'ssh_folder_path';

  String? _sshFolderPath;
  bool _loaded = false;

  String? get sshFolderPath => _sshFolderPath;
  bool get hasAccess => _sshFolderPath != null;
  bool get isLoaded => _loaded;

  /// Load settings from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _sshFolderPath = prefs.getString(_sshFolderPathKey);
    _loaded = true;
    notifyListeners();
  }

  /// Set SSH folder path
  Future<void> setSshFolderPath(String? path) async {
    _sshFolderPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_sshFolderPathKey, path);
    } else {
      await prefs.remove(_sshFolderPathKey);
    }
    notifyListeners();
  }
}
