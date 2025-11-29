import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Update channel - stable (releases) or nightly (CI builds)
enum UpdateChannel { stable, nightly }

/// Configuration for the update service
class UpdateConfig {
  final String owner;
  final String repo;
  final String currentVersion;
  final String? currentCommit;
  final Duration checkInterval;
  final UpdateChannel channel;

  const UpdateConfig({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    this.currentCommit,
    this.checkInterval = const Duration(hours: 10),
    this.channel = UpdateChannel.stable,
  });
}

/// Information about an available update
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;
  final bool isNightly;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    this.isNightly = false,
  });

  @override
  String toString() => 'UpdateInfo(version: $version, downloadUrl: $downloadUrl, isNightly: $isNightly)';
}

/// Service for checking and handling app updates from GitHub Releases or CI
class UpdateService {
  final UpdateConfig config;
  final http.Client? httpClient;
  Timer? _periodicTimer;

  static const String _lastCheckKey = 'update_last_check';
  static const String _skippedVersionKey = 'update_skipped_version';
  static const String _skippedCommitKey = 'update_skipped_commit';

  UpdateService(this.config, {this.httpClient});

  http.Client get _client => httpClient ?? http.Client();

  /// Check for updates based on channel
  Future<UpdateInfo?> checkForUpdate() async {
    if (config.channel == UpdateChannel.nightly) {
      return _checkForNightlyUpdate(checkSkipped: true);
    }
    return _checkForStableUpdate(checkSkipped: true);
  }

  /// Force check for updates (ignores interval and skipped version)
  Future<UpdateInfo?> forceCheckForUpdate() async {
    if (config.channel == UpdateChannel.nightly) {
      return _checkForNightlyUpdate(checkSkipped: false);
    }
    return _checkForStableUpdate(checkSkipped: false);
  }

  /// Check for stable (release) updates
  Future<UpdateInfo?> _checkForStableUpdate({required bool checkSkipped}) async {
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
      return _parseReleaseData(data, checkSkipped: checkSkipped);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Check for nightly (CI) updates
  Future<UpdateInfo?> _checkForNightlyUpdate({required bool checkSkipped}) async {
    try {
      // Get latest successful workflow run
      final url = Uri.parse(
        'https://api.github.com/repos/${config.owner}/${config.repo}/actions/runs?branch=main&status=success&per_page=1',
      );

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to check for nightly updates: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final runs = data['workflow_runs'] as List<dynamic>?;

      if (runs == null || runs.isEmpty) {
        debugPrint('No successful workflow runs found');
        return null;
      }

      final latestRun = runs.first as Map<String, dynamic>;
      final commitSha = latestRun['head_sha'] as String?;
      final runId = latestRun['id'] as int?;
      final createdAt = latestRun['created_at'] as String?;
      final commitMessage = latestRun['head_commit']?['message'] as String? ?? '';

      if (commitSha == null || runId == null) return null;

      // Check if this is a new commit
      if (config.currentCommit != null && commitSha == config.currentCommit) {
        return null;
      }

      // Check if user skipped this commit
      if (checkSkipped) {
        final prefs = await SharedPreferences.getInstance();
        final skippedCommit = prefs.getString(_skippedCommitKey);
        if (skippedCommit == commitSha) {
          return null;
        }
      }

      // Build nightly.link download URL
      final downloadUrl = _getNightlyDownloadUrl(commitSha);

      return UpdateInfo(
        version: 'nightly-${commitSha.substring(0, 7)}',
        downloadUrl: downloadUrl,
        releaseNotes: 'Nightly build from commit:\n$commitMessage',
        publishedAt: createdAt != null ? DateTime.parse(createdAt) : DateTime.now(),
        isNightly: true,
      );
    } catch (e) {
      debugPrint('Error checking for nightly updates: $e');
      return null;
    }
  }

  /// Get nightly.link download URL for current platform
  String _getNightlyDownloadUrl(String commitSha) {
    final artifactName = _getNightlyArtifactName(commitSha);
    return 'https://nightly.link/${config.owner}/${config.repo}/actions/runs/latest/$artifactName';
  }

  /// Get artifact name for nightly builds
  String _getNightlyArtifactName(String commitSha) {
    if (Platform.isMacOS) {
      return 'macos-app-$commitSha.zip';
    } else if (Platform.isWindows) {
      return 'windows-zip-$commitSha.zip';
    } else if (Platform.isLinux) {
      return 'linux-appimage-$commitSha.zip';
    } else if (Platform.isAndroid) {
      return 'android-apk-$commitSha.zip';
    } else if (Platform.isIOS) {
      return 'ios-ipa-$commitSha.zip';
    }
    return 'unknown';
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
  @visibleForTesting
  String? getDownloadUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List<dynamic>?;
    if (assets == null || assets.isEmpty) return null;

    final pattern = getPlatformPattern();
    if (pattern == null) {
      return releaseData['html_url'] as String?;
    }

    for (final asset in assets) {
      final name = asset['name'] as String?;
      if (name != null && name.contains(pattern)) {
        return asset['browser_download_url'] as String?;
      }
    }

    return releaseData['html_url'] as String?;
  }

  /// Get the file pattern for current platform
  @visibleForTesting
  String? getPlatformPattern() {
    if (Platform.isMacOS) {
      return '.dmg';
    } else if (Platform.isWindows) {
      return '-windows.zip';
    } else if (Platform.isLinux) {
      return '.AppImage';
    } else if (Platform.isAndroid) {
      return '.apk';
    } else if (Platform.isIOS) {
      return null;
    }
    return null;
  }

  /// Compare semantic versions
  @visibleForTesting
  static bool isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

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

  /// Mark version as skipped
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    if (version.startsWith('nightly-')) {
      // Extract commit SHA from "nightly-abc1234"
      final commit = version.substring(8);
      await prefs.setString(_skippedCommitKey, commit);
    } else {
      await prefs.setString(_skippedVersionKey, version);
    }
  }

  /// Clear skipped version
  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skippedVersionKey);
    await prefs.remove(_skippedCommitKey);
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
    _checkAndNotify(onUpdateAvailable);
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
