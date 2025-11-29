import 'package:flutter/material.dart';

import 'core/updater/update_service.dart';
import 'features/workspace/workspace_page.dart';

/// Current app version - update this on each release
const String appVersion = '0.2.2';

/// GitHub repository for updates
const String githubOwner = 'alexmakeev';
const String githubRepo = 'hive-terminal';

void main() {
  runApp(const HiveTerminalApp());
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
    _updateService = UpdateService(
      const UpdateConfig(
        owner: githubOwner,
        repo: githubRepo,
        currentVersion: appVersion,
        checkInterval: Duration(hours: 24),
      ),
    );

    // Start periodic update checks after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateService.startPeriodicChecks(_showUpdateDialog);
    });
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  void _showUpdateDialog(UpdateInfo update) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${update.version} is available.'),
            const SizedBox(height: 8),
            Text(
              'Current version: $appVersion',
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
      home: const WorkspacePage(),
    );
  }
}
