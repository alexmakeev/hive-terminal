import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Configuration for the update service
class UpdateConfig {
  final String owner;
  final String repo;
  final String currentVersion;
  final Duration checkInterval;

  const UpdateConfig({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    this.checkInterval = const Duration(hours: 10),
  });
}

/// Information about an available update
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });
}

/// Service for checking and handling app updates from GitHub Releases
class UpdateService {
  final UpdateConfig config;
  Timer? _periodicTimer;

  static const String _lastCheckKey = 'update_last_check';
  static const String _skippedVersionKey = 'update_skipped_version';

  UpdateService(this.config);

  /// Check for updates on GitHub Releases
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/${config.owner}/${config.repo}/releases/latest',
      );

      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to check for updates: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;

      if (tagName == null) return null;

      // Remove 'v' prefix if present
      final latestVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      // Compare versions
      if (!_isNewerVersion(latestVersion, config.currentVersion)) {
        return null;
      }

      // Check if user skipped this version
      final prefs = await SharedPreferences.getInstance();
      final skippedVersion = prefs.getString(_skippedVersionKey);
      if (skippedVersion == latestVersion) {
        return null;
      }

      // Find download URL for current platform
      final downloadUrl = _getDownloadUrl(data);
      if (downloadUrl == null) {
        // Fallback to release page
        return UpdateInfo(
          version: latestVersion,
          downloadUrl: data['html_url'] as String? ??
              'https://github.com/${config.owner}/${config.repo}/releases/latest',
          releaseNotes: data['body'] as String? ?? '',
          publishedAt: DateTime.parse(data['published_at'] as String),
        );
      }

      return UpdateInfo(
        version: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: data['body'] as String? ?? '',
        publishedAt: DateTime.parse(data['published_at'] as String),
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Get platform-specific download URL from release assets
  String? _getDownloadUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List<dynamic>?;
    if (assets == null || assets.isEmpty) return null;

    String pattern;
    if (Platform.isMacOS) {
      pattern = '.dmg';
    } else if (Platform.isWindows) {
      pattern = '.msix';
    } else if (Platform.isLinux) {
      pattern = '.AppImage';
    } else if (Platform.isAndroid) {
      pattern = '.apk';
    } else if (Platform.isIOS) {
      // iOS uses App Store, return release page
      return releaseData['html_url'] as String?;
    } else {
      return null;
    }

    for (final asset in assets) {
      final name = asset['name'] as String?;
      if (name != null && name.contains(pattern)) {
        return asset['browser_download_url'] as String?;
      }
    }

    // Fallback to release page if no matching asset
    return releaseData['html_url'] as String?;
  }

  /// Compare semantic versions
  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (latestParts.length < 3) {
        latestParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

      for (var i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }

  /// Open download URL in browser
  Future<bool> openDownloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Mark version as skipped (user chose "Skip this version")
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
  }

  /// Record that we checked for updates
  Future<void> recordCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Check if enough time has passed since last check
  Future<bool> shouldCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey);

    if (lastCheck == null) return true;

    final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
    return DateTime.now().difference(lastCheckTime) >= config.checkInterval;
  }

  /// Start periodic update checks
  void startPeriodicChecks(void Function(UpdateInfo) onUpdateAvailable) {
    // Check immediately on start
    _checkAndNotify(onUpdateAvailable);

    // Then check periodically
    _periodicTimer = Timer.periodic(config.checkInterval, (_) {
      _checkAndNotify(onUpdateAvailable);
    });
  }

  Future<void> _checkAndNotify(void Function(UpdateInfo) onUpdateAvailable) async {
    if (!await shouldCheck()) return;

    final update = await checkForUpdate();
    await recordCheck();

    if (update != null) {
      onUpdateAvailable(update);
    }
  }

  /// Stop periodic update checks
  void stopPeriodicChecks() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void dispose() {
    stopPeriodicChecks();
  }
}
