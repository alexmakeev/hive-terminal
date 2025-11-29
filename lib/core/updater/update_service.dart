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

  @override
  String toString() => 'UpdateInfo(version: $version, downloadUrl: $downloadUrl)';
}

/// Service for checking and handling app updates from GitHub Releases
class UpdateService {
  final UpdateConfig config;
  final http.Client? httpClient;
  Timer? _periodicTimer;

  static const String _lastCheckKey = 'update_last_check';
  static const String _skippedVersionKey = 'update_skipped_version';

  UpdateService(this.config, {this.httpClient});

  http.Client get _client => httpClient ?? http.Client();

  /// Check for updates on GitHub Releases
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/${config.owner}/${config.repo}/releases/latest',
      );

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to check for updates: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseReleaseData(data, checkSkipped: true);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Force check for updates (ignores interval and skipped version)
  Future<UpdateInfo?> forceCheckForUpdate() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/${config.owner}/${config.repo}/releases/latest',
      );

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to check for updates: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseReleaseData(data, checkSkipped: false);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Parse release data from GitHub API response
  Future<UpdateInfo?> _parseReleaseData(
    Map<String, dynamic> data, {
    required bool checkSkipped,
  }) async {
    final tagName = data['tag_name'] as String?;
    if (tagName == null) return null;

    // Remove 'v' prefix if present
    final latestVersion = tagName.startsWith('v')
        ? tagName.substring(1)
        : tagName;

    // Compare versions
    if (!isNewerVersion(latestVersion, config.currentVersion)) {
      return null;
    }

    // Check if user skipped this version
    if (checkSkipped) {
      final prefs = await SharedPreferences.getInstance();
      final skippedVersion = prefs.getString(_skippedVersionKey);
      if (skippedVersion == latestVersion) {
        return null;
      }
    }

    // Find download URL for current platform
    final downloadUrl = getDownloadUrl(data);

    return UpdateInfo(
      version: latestVersion,
      downloadUrl: downloadUrl ?? data['html_url'] as String? ??
          'https://github.com/${config.owner}/${config.repo}/releases/latest',
      releaseNotes: data['body'] as String? ?? '',
      publishedAt: DateTime.parse(data['published_at'] as String),
    );
  }

  /// Get platform-specific download URL from release assets
  /// Made public for testing
  @visibleForTesting
  String? getDownloadUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List<dynamic>?;
    if (assets == null || assets.isEmpty) return null;

    final pattern = getPlatformPattern();
    if (pattern == null) {
      // Unknown platform, fallback to release page
      return releaseData['html_url'] as String?;
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

  /// Get the file pattern for current platform
  /// Made public for testing
  @visibleForTesting
  String? getPlatformPattern() {
    if (Platform.isMacOS) {
      return '.dmg';
    } else if (Platform.isWindows) {
      return '-windows.zip';
    } else if (Platform.isLinux) {
      return '-linux.tar.gz';
    } else if (Platform.isAndroid) {
      return '.apk';
    } else if (Platform.isIOS) {
      return null; // iOS uses App Store
    }
    return null;
  }

  /// Compare semantic versions
  /// Made public for testing
  @visibleForTesting
  static bool isNewerVersion(String latest, String current) {
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

  /// Clear skipped version
  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skippedVersionKey);
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
