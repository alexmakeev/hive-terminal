import 'package:flutter/material.dart';

import 'core/updater/update_service.dart';

/// Current app version - update this on each release
const String appVersion = '0.1.0';

/// GitHub repository for updates
const String githubOwner = 'alexmakeev';
const String githubRepo = 'hive-terminal';

void main() {
  runApp(const HiveTerminalApp());
}

class HiveTerminalApp extends StatelessWidget {
  const HiveTerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hive Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final UpdateService _updateService;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _updateService = UpdateService(
      const UpdateConfig(
        owner: githubOwner,
        repo: githubRepo,
        currentVersion: appVersion,
        checkInterval: Duration(hours: 10),
      ),
    );

    // Start periodic update checks
    _updateService.startPeriodicChecks(_showUpdateDialog);
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  void _showUpdateDialog(UpdateInfo update) {
    if (!mounted) return;

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

  Future<void> _manualCheckUpdate() async {
    setState(() => _checkingUpdate = true);

    final update = await _updateService.checkForUpdate();

    setState(() => _checkingUpdate = false);

    if (!mounted) return;

    if (update != null) {
      _showUpdateDialog(update);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are running the latest version'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // Logo placeholder
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A4A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF4A4A6A),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.terminal,
                    size: 64,
                    color: Color(0xFF00D9FF),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'Hive Terminal',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Version
                Text(
                  'v$appVersion',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // Description
                Text(
                  'Multi-agent terminal for AI orchestration',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 48),

                // Features list
                _buildFeatureItem(Icons.lan, 'MCP Protocol'),
                _buildFeatureItem(Icons.mic, 'Voice Control'),
                _buildFeatureItem(Icons.grid_view, '10+ Sessions'),
                _buildFeatureItem(Icons.swipe, 'Swipe Navigation'),

                const SizedBox(height: 48),

                // Check for updates button
                OutlinedButton.icon(
                  onPressed: _checkingUpdate ? null : _manualCheckUpdate,
                  icon: _checkingUpdate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_checkingUpdate ? 'Checking...' : 'Check for Updates'),
                ),
                const SizedBox(height: 16),

                // Footer
                Text(
                  'Open Source',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF00D9FF),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
