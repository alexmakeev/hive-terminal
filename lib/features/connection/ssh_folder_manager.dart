import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages access to the SSH keys folder on macOS
class SshFolderManager extends ChangeNotifier {
  static const String _sshFolderPathKey = 'ssh_folder_path';

  String? _sshFolderPath;
  bool _loaded = false;

  String? get sshFolderPath => _sshFolderPath;
  bool get isLoaded => _loaded;
  bool get hasAccess => _sshFolderPath != null;

  /// Load saved SSH folder path
  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _sshFolderPath = prefs.getString(_sshFolderPathKey);

      // Verify the folder still exists and is accessible
      if (_sshFolderPath != null) {
        final dir = Directory(_sshFolderPath!);
        if (!await dir.exists()) {
          debugPrint('[SSH] Saved folder no longer exists: $_sshFolderPath');
          _sshFolderPath = null;
          await prefs.remove(_sshFolderPathKey);
        } else {
          // Try to list files to verify access
          try {
            await dir.list().first;
            debugPrint('[SSH] Folder access verified: $_sshFolderPath');
          } catch (e) {
            debugPrint('[SSH] Cannot access folder: $e');
            _sshFolderPath = null;
            await prefs.remove(_sshFolderPathKey);
          }
        }
      }

      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SSH] Error loading folder path: $e');
      _loaded = true;
    }
  }

  /// Prompt user to select SSH folder
  Future<bool> selectFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select SSH Keys Folder',
        initialDirectory: _getDefaultSshPath(),
      );

      if (result != null) {
        // Verify it's accessible
        final dir = Directory(result);
        if (await dir.exists()) {
          try {
            await dir.list().toList();
            _sshFolderPath = result;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_sshFolderPathKey, result);

            debugPrint('[SSH] Folder selected: $result');
            notifyListeners();
            return true;
          } catch (e) {
            debugPrint('[SSH] Cannot read folder: $e');
            return false;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('[SSH] Error selecting folder: $e');
      return false;
    }
  }

  /// Clear saved folder (revoke access)
  Future<void> clearFolder() async {
    _sshFolderPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sshFolderPathKey);
    notifyListeners();
  }

  /// Get default SSH path hint
  String? _getDefaultSshPath() {
    if (Platform.isMacOS || Platform.isLinux) {
      final user = Platform.environment['USER'];
      if (user != null) {
        return '/Users/$user/.ssh';
      }
    }
    return null;
  }

  /// Get list of available key files in the folder
  Future<List<File>> getKeyFiles() async {
    if (_sshFolderPath == null) return [];

    try {
      final dir = Directory(_sshFolderPath!);
      final keyNames = ['id_ed25519', 'id_rsa', 'id_ecdsa', 'id_dsa'];
      final files = <File>[];

      for (final name in keyNames) {
        final file = File('${dir.path}/$name');
        if (await file.exists()) {
          files.add(file);
        }
      }

      return files;
    } catch (e) {
      debugPrint('[SSH] Error listing keys: $e');
      return [];
    }
  }
}
