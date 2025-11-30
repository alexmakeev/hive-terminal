import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings manager
class SettingsManager extends ChangeNotifier {
  static const String _focusZoomKey = 'focus_zoom';
  static const String _sshFolderPathKey = 'ssh_folder_path';

  double _focusZoom = 1.3; // Default 30% zoom on focus
  String? _sshFolderPath;
  bool _loaded = false;

  double get focusZoom => _focusZoom;
  String? get sshFolderPath => _sshFolderPath;
  bool get hasAccess => _sshFolderPath != null;
  bool get isLoaded => _loaded;

  /// Load settings from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _focusZoom = prefs.getDouble(_focusZoomKey) ?? 1.3;
    _sshFolderPath = prefs.getString(_sshFolderPathKey);
    _loaded = true;
    notifyListeners();
  }

  /// Set focus zoom level (1.0 = no zoom, 1.5 = 150%)
  Future<void> setFocusZoom(double zoom) async {
    _focusZoom = zoom.clamp(1.0, 1.5);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_focusZoomKey, _focusZoom);
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
