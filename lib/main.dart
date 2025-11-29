import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/logging/file_logger.dart';
import 'core/updater/update_service.dart';
import 'features/workspace/workspace_page.dart';

/// Current app version - update this on each release
const String appVersion = '0.3.4';

/// Current commit SHA (set by CI for nightly builds)
const String appCommit = String.fromEnvironment('GIT_COMMIT', defaultValue: '');

/// Update channel: 'stable' (default) or 'nightly'
const String updateChannelStr = String.fromEnvironment('UPDATE_CHANNEL', defaultValue: 'stable');

/// GitHub repository for updates
const String githubOwner = 'alexmakeev';
const String githubRepo = 'hive-terminal';

void main() async {
  // Catch all errors in the zone
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize file logger
    await logger.init();
    await logger.log('main() started');
    await logger.log('App version: $appVersion');
    await logger.log('Dart version: ${Platform.version}');

    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.logError(
        'Flutter error: ${details.exceptionAsString()}',
        details.exception,
        details.stack,
      );
      FlutterError.presentError(details);
    };

    // Handle errors not caught by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.logError('Platform error', error, stack);
      return true;
    };

    await logger.log('Starting app...');
    runApp(const HiveTerminalApp());
    await logger.log('runApp() completed');
  }, (error, stack) async {
    // This catches errors outside of Flutter's error handling
    await logger.logError('Unhandled zone error', error, stack);
    if (kDebugMode) {
      print('Unhandled error: $error\n$stack');
    }
  });
}

class HiveTerminalApp extends StatefulWidget {
  const HiveTerminalApp({super.key});

  @override
  State<HiveTerminalApp> createState() => _HiveTerminalAppState();
}

class _HiveTerminalAppState extends State<HiveTerminalApp> {
  late final UpdateService _updateService;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    logger.log('HiveTerminalApp.initState()');

    final updateChannel = updateChannelStr == 'nightly'
        ? UpdateChannel.nightly
        : UpdateChannel.stable;

    logger.log('Update channel: $updateChannelStr');
    if (appCommit.isNotEmpty) {
      logger.log('Commit: $appCommit');
    }

    _updateService = UpdateService(
      UpdateConfig(
        owner: githubOwner,
        repo: githubRepo,
        currentVersion: appVersion,
        currentCommit: appCommit.isNotEmpty ? appCommit : null,
        checkInterval: const Duration(hours: 24),
        channel: updateChannel,
      ),
    );

    // Start periodic update checks after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logger.log('First frame rendered, starting update checks');
      _updateService.startPeriodicChecks(_showUpdateDialog);
    });
  }

  @override
  void dispose() {
    logger.log('HiveTerminalApp.dispose()');
    _updateService.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    logger.log('Manual update check requested');
    final context = _navigatorKey.currentContext;
    if (context == null) {
      logger.log('No context available for update check');
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final update = await _updateService.forceCheckForUpdate();
    logger.log('Update check result: ${update?.version ?? "no update"}');

    // Hide loading indicator
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (update != null) {
      _showUpdateDialog(update);
    } else {
      // Show "no updates" message
      if (_navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('You are on the latest version ($appVersion)'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showAboutDialog() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final versionInfo = appCommit.isNotEmpty
        ? '$appVersion (${appCommit.substring(0, 7)})'
        : appVersion;
    final channelInfo = updateChannelStr == 'nightly' ? ' [NIGHTLY]' : '';

    showAboutDialog(
      context: context,
      applicationName: 'Hive Terminal$channelInfo',
      applicationVersion: versionInfo,
      applicationIcon: Icon(
        Icons.hive,
        size: 48,
        color: updateChannelStr == 'nightly'
            ? const Color(0xFF4CAF50)  // Green for nightly
            : const Color(0xFFFF9800), // Orange for stable
      ),
      children: [
        const Text('Mobile terminal for managing AI agents.'),
        const SizedBox(height: 16),
        const Text('SSH client with AI CLI integration.'),
        if (updateChannelStr == 'nightly') ...[
          const SizedBox(height: 16),
          const Text(
            'This is a nightly build for testing.',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Log file: ${logger.logFilePath ?? "not available"}',
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  void _showUpdateDialog(UpdateInfo update) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final currentVersionText = appCommit.isNotEmpty
        ? '$appVersion (${appCommit.substring(0, 7)})'
        : appVersion;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(update.isNightly ? 'Nightly Build Available' : 'Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(update.isNightly
                ? 'Build ${update.version} is available.'
                : 'Version ${update.version} is available.'),
            const SizedBox(height: 8),
            Text(
              'Current: $currentVersionText',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Release notes:'),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    update.releaseNotes,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _updateService.skipVersion(update.version);
              Navigator.of(context).pop();
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              _updateService.openDownloadUrl(update.downloadUrl);
              Navigator.of(context).pop();
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    logger.log('HiveTerminalApp.build()');
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Hive Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9800),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1208),
      ),
      home: WorkspacePage(
        onCheckForUpdates: _checkForUpdates,
        onShowAbout: _showAboutDialog,
      ),
    );
  }
}
